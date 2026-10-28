## Context

Findings come from the `adopt-openspec` baseline. Provider: `scaleway/scaleway ~> 2.86`; tool: OpenTofu/Terraform `>= 1.10.7` (cross-variable validation needs 1.9, available).

## Goals / Non-Goals

**Goals:** make descriptions true, give clear plan-time errors for references that already failed, warn about silently ignored input, keep every working config working.

**Non-Goals:** redesigning deletion protection, renaming outputs, changing the principal model of policies, adding a "soon" window.

## Decisions

### Deletion protection (issue 2) stays a documentation fix
Verified with a scratch configuration: a `terraform_data` guard with `prevent_destroy = true` that disappears because its `for_each` becomes `{}` makes the plan fail with "Instance cannot be destroyed"; `tofu destroy` fails the same way. `prevent_destroy` cannot reference a variable, so one resource cannot be both switchable and protected. The only mechanisms that make the flag switchable (`lifecycle { destroy = false }` / `removed` blocks) raise `required_version` (major) or are not conditional. The guards still protect (destroy, removal of an entry). Lifting protection is a deliberate, visible state operation: `tofu state rm` of the guard addresses, which leaves the protected resources untouched. Documented in the `enable_deletion_protection` description and the README. Cited: `quality-production-readiness` (documented, honest), `terraform-versioning`.

### Cleanup (issue 3)
`prevent_destroy = false` is the default; the `lifecycle` block of applications and policies is removed, the group keeps `ignore_changes`. No plan or state change.

### Validations (issues 5, 9, 10)
Added to the variable that carries the input, with cross-variable references (`var.applications`, `var.groups`, `var.project_name`) and static messages naming the input (`terraform-variables`: validation names what is accepted).
- `api_keys`: `application_key` is a key of `applications`.
- `groups`: each `application_keys` entry is a key of `applications`; `substr(user_id, 0, 8)` is unique within the group. Both skip `external_membership = true` groups, which create no membership and so worked before.
- `policies`: only the entry that selects the principal is checked (`user_ids` empty and `no_principal` false: first `group_keys` entry; then first `application_keys` entry), because ignored entries never failed. HCL `||` does not short-circuit, so the checks use a conditional expression to guard `[0]`.
- `ssh_keys`: `project_name != null` or every key has a `project_id`.
Membership keys are not changed (issue 5): changing them would move every user membership address and need `moved` blocks that cannot be derived for all inputs; a validation turns the collision into a clear error at no state cost. Duplicated user IDs in one group also share a prefix and are rejected by the same rule (they were a "duplicate object key" error already).

### Check for ignored principals (issue 4)
A `check "policy_single_principal"` asserts that a local list of policy keys with ignored principals is empty. A policy has ignored entries when `length(user_ids) + length(group_keys) + length(application_keys)` exceeds 1, or exceeds 0 with `no_principal = true`. A `check` warns and never fails the plan, so nothing that works breaks (`terraform-security`: dangerous but legal configurations are reported with `check`). It is exercised in unit tests with `expect_failures = [check.policy_single_principal]`.

### Descriptions (issues 1, 6, 7, 8)
Words only. `api_keys_expiring_soon` keeps its name and behaviour (stable shape, `terraform-outputs`); the description says it lists every key with an `expires_at`. The `tags` colon claim is dropped because Scaleway documents no such rule and validating a guess could reject working configs.

## Perpetual diff and state
No resource argument changes, so the second plan stays empty. No address changes: no `moved` block.

## Risks
- A configuration that relied on the (non-working) flag sequence now has a documented one.
- Policy validation messages name the input, not the policy key (static `error_message`).

## Migration
None.
