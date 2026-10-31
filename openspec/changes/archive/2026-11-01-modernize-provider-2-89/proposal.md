## Why

The module (v2.0.0) is on provider `~> 2.89` but still carries the shape of the first release: a `project_name` lookup through `data.scaleway_account_project`, three parallel principal lists per policy that silently keep only the first entry (plus a `check` to warn about it), a group that fights its own memberships with `ignore_changes`, a single sensitive `api_keys` output that hides non-secret values and keeps every secret key in state by default, and 20 outputs of which seven only echo another one. It also cannot do two things an IAM module is used for: attach a user the module invites to a group (the user ID is unknown at plan time, so it takes two applies), and restrict a policy rule with a `condition` (IP allow-list, time window).

This change is the v3.0.0 major: a breaking cleanup to the cross-module conventions (`project_id`, secure defaults), the provider's own membership model (`external_membership`), and the 2.89.0 schema. Standards applied: `terraform-versioning`, `terraform-variables`, `terraform-outputs`, `terraform-security`, `terraform-state`, `terraform-providers`, `terraform-testing`, `quality-simplicity`, `quality-security`, `quality-production-readiness`.

## What Changes

Gap analysis of the 2.89.0 schema (`/tmp/scw-schema/schema-2.89.0.json`) against the seven resources and one data source the module uses, and the adjacent IAM family (`iam_saml`, `iam_saml_certificate`, `iam_scim`, `iam_scim_token`, the `iam_*` data sources, the ephemeral `iam_api_key`). There is no organization-settings, MFA-policy or login-settings resource in 2.89.0: `scaleway_iam_user` only exposes `mfa` and `locked` as read-only attributes.

### Adopted features

| # | Feature | Resource / argument (provider version) |
|---|---------|----------------------------------------|
| 1 | Policy rule `condition` (CEL expression: IP allow-list, time window) | `scaleway_iam_policy.rule.condition`, present in the 2.89.0 schema (exists before 2.86; not exposed until now) |
| 2 | `groups[*].user_keys`: add users created by the module to a group in one apply | `scaleway_iam_group_membership.user_id` (existing) fed from `scaleway_iam_user.this[key].id` |
| 3 | Group declares `external_membership = true` to the provider, so the module's membership resources are the only membership source and `ignore_changes` goes away | `scaleway_iam_group.external_membership` (present in the 2.89.0 schema) |
| 4 | MFA audit: `users[*].mfa` and `locked` in the `users` output, new `security_audit.users_without_mfa` | `scaleway_iam_user.mfa`, `locked` (computed, 2.89.0 schema) |
| 5 | Secret keys separated from the rest of the API key data: `api_key_secret_keys` (sensitive) and a non-sensitive `api_keys` | `scaleway_iam_api_key.secret_key` (existing), `secret_id` (2.88.0) |
| 6 | Real-date validation of `expires_at`; accurate SSH public key format check (`ecdsa-sha2-nistp256/384/521` instead of the non-existent `ssh-ecdsa`) | validation only |

### Breaking changes (consumer edit)

| # | Change | Consumer edit |
|---|--------|---------------|
| 1 | `project_name` removed; `project_id` added (`string`, default `null` = provider default project); `data.scaleway_account_project` and output `project_id` removed | Replace `project_name = "x"` by `project_id = "<uuid>"` (for example from a `scaleway_account_project` data source in the caller) |
| 2 | `ssh_keys[*].project_id` and `api_keys[*].default_project_id` fall back to the module `project_id` (was: `project_id` fell back to the looked-up project, `default_project_id` had no fallback) | None for SSH keys. API keys without `default_project_id` now get `project_id` as default project (in-place update); set `default_project_id` explicitly or leave `project_id` unset to keep the current value |
| 3 | Validation "SSH key needs a project_id when project_name is not set" removed | None (the key is created in the provider default project) |
| 4 | `policies[*].user_ids`, `group_keys`, `application_keys` (lists) replaced by `user_id`, `group_key`, `application_key` (strings); exactly one of them or `no_principal = true` is required | `group_keys = ["a"]` becomes `group_key = "a"` (same for the others); drop surplus entries |
| 5 | `policies[*].rules[*].organization_id` replaced by `organization_wide` (`bool`, default `false`); `organization_wide` and `project_ids` are mutually exclusive | `organization_id = var.organization_id` becomes `organization_wide = true` |
| 6 | Check `policy_single_principal` removed (the validation in 4 rejects what it warned about) | None |
| 7 | `groups[*].external_membership` removed; the group always declares external membership to the provider | Delete the attribute. A group that had `external_membership = true` and non-empty `application_keys`/`user_ids` now creates those memberships: empty the lists to keep membership managed elsewhere |
| 8 | Output `api_keys` is no longer sensitive and no longer has `secret_key`; secret keys move to the new sensitive `api_key_secret_keys` (only keys without `secret_id`) | `module.iam.api_keys["k"].secret_key` becomes `module.iam.api_key_secret_keys["k"]` |
| 9 | Outputs removed: `project_id`, `summary`, `api_key_access_keys`, `api_key_ids`, `ssh_key_ids`, `ssh_key_fingerprints`, `ssh_key_public_keys` | Use `api_keys["k"].access_key` / `.id`, `ssh_keys["k"].id` / `.fingerprint`, `length()` of the maps; the public key is the caller's own input |
| 10 | `security_audit.api_keys_expiring_soon` renamed `api_keys_with_expiration` (it never was a time window) | Rename the reference |
| 11 | `require_api_key_secret_id` default `false` becomes `true` (secure by default) | Set `secret_id` on every key (replaces the key, see State) or set `require_api_key_secret_id = false` |
| 12 | `expires_at` must be a real date (`2026-13-45T00:00:00Z` is rejected); public keys of type `ssh-ecdsa` (not a real key type) are rejected | None for valid inputs |

### Simplifications

| # | Simplification |
|---|----------------|
| 1 | Delete `data.tf` and `locals.project_id` (no lookup, no `count`) |
| 2 | Delete the `ignore_changes` on groups and the group `depends_on`; delete redundant `depends_on` on API keys, memberships and policies (references already order them) |
| 3 | Delete locals `application_ids`, `group_ids`, `user_ids` (outputs compute them) and `policies_with_ignored_principals`; the policy `resource` loses three nested ternaries |
| 4 | 20 outputs become 14 (breaking 8, 9) |
| 5 | Replace three-list principal selection by one scalar per principal type with an exactly-one validation |

### Deferred / Rejected

| Item | Decision and reason |
|------|--------------------|
| Ephemeral `scaleway_iam_api_key` (2.89.0; `srn` coming in 2.90.0, unpublished) | Rejected. It mints a new key on every run, is not tracked and not cleaned up when `delete_on_close = false`; it cannot back durable `for_each` API keys declared in a module. State already holds no secret with `secret_id` (2.88.0), which achieves the same goal for managed keys. A consumer who needs a short-lived key for a provider configuration uses the ephemeral resource directly |
| Write-only / ephemeral inputs (`*_wo`, `*_wo_version`) | Not applicable: the module has no secret-bearing input. `secret_id` is an identifier; `scaleway_iam_user.password_wo` is rejected (see below), so `required_version` stays `>= 1.10.7` |
| `iam_user.password_wo`, `password` | Rejected. The module invites people; they set their own credentials. An admin-chosen password is a weaker practice |
| `iam_user.first_name`, `last_name`, `phone_number`, `locale` | Rejected: personal data, no production need for an invitation workflow (`quality-simplicity`) |
| MFA / login enforcement settings | Not available in 2.89.0 (no resource); only the read-only audit in adopted 4 |
| `srn` attributes (all resources, `api_key.creation_ip`, `editable`) | Rejected again: no consumer in the module, `terraform-outputs` forbids exporting every attribute |
| Creating the Secret Manager secret in the module | Rejected again. `scaleway_secret` needs `region`, naming and its own protection; the sibling module `scaleway-secrets-and-keys` owns it; the caller passes its ID |
| `user_key` on `policies` and `api_keys` | Rejected: policies belong on groups; personal API keys are created by the user. `user_id` stays for existing users |
| Existing group/application IDs on policies and groups (`group_id`, `application_id`) | Rejected: no demand; callers wrap existing identities with their own data sources only if a real need appears |
| `iam_saml`, `iam_saml_certificate`, `iam_scim`, `iam_scim_token` (SSO / provisioning) | Rejected: separate product area with a secret-bearing resource (`bearer_token` lands in state); belongs in a dedicated module |
| `iam_*` data sources, `scaleway_account_project(s)` | Rejected: the module creates, it does not read; project lookup is the caller's responsibility (breaking 1) |
| Flipping `require_api_key_expiration` to `true` | Rejected: expiry is a rotation policy (long-running automation keys are legitimate), not a safety default. `require_api_key_secret_id` differs: it protects a secret from state |
| Deletion guards for users and API keys | Rejected: unchanged scope (guards stay on applications, groups, policies) |
| Module-side permission-set scope check | Rejected again (provider checks it at plan time with the live catalogue) |

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `module-contract`: `project_id` replaces `project_name`, defaults, outputs (14), sensitive outputs, security audit, removal of `summary`.
- `applications-and-api-keys`: `default_project_id` fallback, `expires_at` real-date validation, outputs split, `require_api_key_secret_id` default `true`.
- `groups`: `user_keys`, no `external_membership` input, provider-level external membership instead of `ignore_changes`.
- `policies`: scalar principal selection with exactly-one validation, rule `condition`, `organization_wide`; warning check removed.
- `users-and-ssh-keys`: user MFA/lock outputs, SSH key project fallback, public key format.
- `deletion-protection`: unchanged.

## Semver

**Major (v2.0.0 to v3.0.0).** Removed and renamed inputs and outputs, a changed default that alters behaviour (`require_api_key_secret_id`) and a changed meaning (`default_project_id`), per `terraform-versioning`. The provider floor stays `~> 2.89`; `required_version` stays `>= 1.10.7` (nothing uses write-only arguments or ephemeral values).

Inputs and outputs whose type, default or meaning changes:

| Item | Change |
|------|--------|
| `project_name` | removed (breaking 1) |
| `project_id` | new `string`, default `null`, UUID validated |
| `require_api_key_secret_id` | default `false` to `true` |
| `api_keys[*].default_project_id` | meaning: falls back to `project_id` |
| `api_keys[*].expires_at` | validation tightened |
| `groups[*].external_membership` | removed |
| `groups[*].user_keys` | new `list(string)`, default `[]` |
| `policies[*].user_ids`, `group_keys`, `application_keys` | removed; `user_id`, `group_key`, `application_key` added (`optional(string)`) |
| `policies[*].rules[*].organization_id` | removed; `organization_wide` (`bool`, `false`) and `condition` (`optional(string)`) added |
| `ssh_keys[*].project_id` | fallback now `project_id`; validation of `public_key` corrected |
| Outputs | removed: `project_id`, `summary`, `api_key_access_keys`, `api_key_ids`, `ssh_key_ids`, `ssh_key_fingerprints`, `ssh_key_public_keys`. Changed: `api_keys` (not sensitive, no `secret_key`), `users` (adds `mfa`, `locked`), `security_audit` (rename + `users_without_mfa`). New: `api_key_secret_keys` (sensitive) |

## State

- No resource address changes: every resource keeps its label and key, memberships keep their keys (`<group>-app-<key>`, `<group>-user-<8 chars>`), so no `moved` block is needed. New user-key memberships use `<group>-user-key-<key>`.
- Groups: setting `external_membership = true` is an in-place update on each existing group with no API call for membership (provider update path skips membership when the flag is true); the first plan after upgrade shows one update per group, the second is empty. To be proven on a state replay (tasks 8.2).
- Secrets in state: an API key without `secret_id` still stores `secret_key` in state (sensitive); with `require_api_key_secret_id = true` by default the plan now fails for such keys until the consumer chooses. The secret key output is isolated in `api_key_secret_keys` (empty when every key uses `secret_id`). `secret_id` is ForceNew: setting it on an existing key replaces the key (rotation, documented). Emails stay in the sensitive `user_details`. `SECURITY.md` "What lands in state" table updated.
- No new secret-bearing input; `terraform-security` write-only rule is not triggered.

## Impact

- Code: `versions.tf` (unchanged), `variables.tf`, `main.tf`, `outputs.tf`, `locals.tf`; `data.tf` deleted.
- Examples: `examples/minimal` and `examples/complete` (`project_id`, new fields; the complete example drops the project data source from the module call only).
- Docs: `README.md` "Upgrading from v2 to v3" section (every breaking change with its consumer edit), usage sections, terraform-docs block (regenerated by pre-commit), `SECURITY.md`.
- Tests: `tests/main.tftest.hcl` (mock provider; the `scaleway_account_project` mock is removed; a rejected-input run per new validation).
- Specs: the five modified capabilities above.
- Not run: any apply against a real Scaleway organization (separate group in tasks).
