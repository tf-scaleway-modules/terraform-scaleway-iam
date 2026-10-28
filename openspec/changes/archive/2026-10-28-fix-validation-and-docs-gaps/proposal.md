## Why

Writing the baseline of the module (`adopt-openspec`) surfaced ten gaps between what the module says and what it does: documentation that contradicts the code, a deletion-protection sequence that cannot work, comments that point to a precondition that does not exist, and references that fail with a raw index error instead of a validation message. This change fixes them without breaking any configuration that works today.

## What Changes

Each issue was checked against the code (OpenTofu 1.11.14). Decisions follow `terraform-versioning`: prefer the non-breaking fix, and a validation that only rejects inputs that already failed (or produced broken resources) is a fix.

| # | Finding | Decision |
|---|---------|----------|
| 1 | `users` output description says "SENSITIVE - contains PII", but the output is not sensitive and has no email (the contract says so on purpose: the email is in `user_details`) | Doc fix: correct the output description and the file comment. Marking it sensitive would break consumers that read it. |
| 2 | Verified: with the flag `true`, setting it to `false` plans the destruction of the guards, and `prevent_destroy` blocks that plan; `tofu destroy` is blocked too. The documented "set false before destroy" sequence cannot work. `prevent_destroy` cannot read a variable, and the alternatives (`lifecycle.destroy`, a raised `required_version`) are major. | Doc fix: say what the guards really block (destroy, removal of an entry, flipping the flag) and document the working sequence (`tofu state rm` of the guards, then destroy or remove the entry) in the variable description and the README. No code change to the guards. |
| 3 | `prevent_destroy = false # Controlled via precondition below`: no such precondition; `false` is the default | Code cleanup: drop the no-op `lifecycle` setting and the misleading comments. No plan change. |
| 4 | A policy uses the first entry of the highest-priority principal list; the rest is silently ignored | A `check` block warns, naming the policy, when entries are ignored; description and README state the rule. Rejecting such configs would break configs that work. |
| 5 | Membership key `<group>-user-<first 8 characters>` collides for two users of one group sharing a prefix (a raw "duplicate object key" error today) | New validation on `groups` rejecting duplicate prefixes (groups with `external_membership = true` are skipped: they create no membership). Keys are unchanged, so no `moved` block and no state change. |
| 6 | `security_audit.api_keys_expiring_soon` lists every key with `expires_at`, whatever the date | Doc fix: the description states the behaviour. Renaming or re-defining the key is breaking, and a "soon" window needs `timestamp()` (a permanent output diff). |
| 7 | `tags` description says tags cannot contain colons; nothing validates it | Doc fix: Scaleway documents no such rule (only count and length limits), so the unverified claim is removed instead of enforced. Enforcing it could reject configs that work. |
| 8 | `require_api_key_expiration` description says "fail validation"; it is a resource precondition | Doc fix: the description says the plan fails on the API key. |
| 9 | `coalesce(project_id, local.project_id)` errors when both are unset | New validation on `ssh_keys`: a key needs `project_id` when `project_name` is `null`. Rejects only configs that already failed. |
| 10 | Unknown `application_key`, `application_keys` or `group_keys` entries fail with an index error | New validations naming the input. They check only references that are used today: API key owner; group `application_keys` unless `external_membership`; the single entry that selects a policy principal. |

### Semver

**Patch.** No input, output, default, resource address or version floor changes. The three new validations reject only configurations that already failed at plan time; the `check` block emits a warning and never fails a plan. (`terraform-versioning` does not list checks: treated as a fix because it adds no input, output or resource.)

Inputs whose meaning changes: none. Description changes: `tags`, `enable_deletion_protection`, `require_api_key_expiration`, `policies`. Outputs: description of `users` and `security_audit`; shapes unchanged.

### State and security

Nothing new lands in state; no secret-bearing input or output is added, so `SECURITY.md` is not created. State is unchanged: no address moves (hence no `moved` block), and the removed `prevent_destroy = false` is the default.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `deletion-protection`: guards block flag removal as well as destroy; lifting protection is documented.
- `module-contract`: tags are not validated by the module; `users` description; audit output wording.
- `applications-and-api-keys`: `application_key` must reference an existing application.
- `groups`: `application_keys` must reference existing applications; user ID prefixes unique per group.
- `policies`: the selected principal must exist; a `check` warns about ignored principals.
- `users-and-ssh-keys`: an SSH key needs a project.

## Impact

- Modified: `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `README.md` (outside the terraform-docs block, plus regenerated block), new `tests/main.tftest.hcl`.
- `examples/complete` and `examples/minimal` need no change: no input is added or renamed, and they already use one principal per policy and valid references.
- Consumers: none broken. Anyone relying on the documented flag sequence must use the `tofu state rm` sequence instead.
