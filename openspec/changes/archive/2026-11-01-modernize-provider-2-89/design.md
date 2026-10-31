## Context

Module v2.0.0 (provider `~> 2.89`, tool `>= 1.10.7`). Resources: `scaleway_iam_application`, `iam_api_key`, `iam_group`, `iam_group_membership` (two resources), `iam_policy`, `iam_user`, `iam_ssh_key`, `terraform_data` guards, plus `data.scaleway_account_project`. Facts below were read from the 2.89.0 schema (`/tmp/scw-schema/schema-2.89.0.json`) and the provider source at tag v2.89.0 (`internal/services/iam/{group,api_key,policy}.go`). See proposal.md for the adopted, breaking and rejected tables. Standards: `terraform-versioning`, `terraform-variables`, `terraform-outputs`, `terraform-security`, `terraform-state`, `terraform-providers`, `terraform-testing`, `terraform-code-style`, `quality-simplicity`, `quality-security`.

## Goals / Non-Goals

Goals: align with the cross-module conventions where IAM allows it, remove silent behaviours (first-wins principals, `ignore_changes`), make the secure path the default, and close the two functional gaps (users in groups in one apply, rule conditions).

Non-goals: SSO/SCIM, user profile fields, secret creation, ephemeral keys, any change to the deletion guards.

## Decisions

### 1. Organization and project
IAM resources are organization-scoped: `organization_id` stays required (applications, groups, policies, users; `iam_ssh_key.organization_id` is computed). The project convention only applies to project-scoped settings: an SSH key's `project_id` (`iam_ssh_key`, optional+computed) and an API key's `default_project_id` (`iam_api_key`, optional+computed, updated in place).

New `project_id` (`string`, `null`, UUID regex, same message style as the other UUID checks) replaces `project_name` and the data source. SSH keys: `project_id = coalesce-null(key.project_id, var.project_id)` written as `each.value.project_id != null ? each.value.project_id : var.project_id` (a plain `coalesce` errors when both are null). API keys: `default_project_id` likewise. Per-key overrides stay (the module is organization-wide, so keys in several projects are common); a second input would be needed otherwise.

Perpetual diff: both arguments are optional+computed, so a `null` result never diffs against the project the API returned. Existing SSH keys: the consumer passes the same project ID that `project_name` resolved to, the value is identical, no diff. Existing API keys without `default_project_id` change in place if `project_id` is set (breaking 2); documented in the upgrade section with the opt-out (leave `project_id` unset or set the key's value explicitly).

Alternative rejected: keep `project_name` as a deprecated input for one version (`terraform-versioning` suggests deprecation when feasible): it would keep the data source, `count` and a dual input, which is exactly what this change removes. The major bump and the README upgrade section carry the edit.

### 2. Group membership model
Provider `scaleway_iam_group.external_membership` (schema 2.89.0): "Handle user and application memberships externally". Source: when true, Create/Update skip `SetGroupMembers` and Read does not write `user_ids`/`application_ids` to state. The module manages memberships with `scaleway_iam_group_membership`, which is exactly that case. Passing `external_membership = true` on every group removes the need for `lifecycle.ignore_changes` and for `depends_on` on users/applications (the group references neither).

Migration: existing groups flip the flag in place. State still holds `user_ids`/`application_ids` from earlier reads; config sets neither, so the first plan shows `user_ids`/`application_ids` going to null as part of the same update and no API membership call. After apply the state attributes are null and the second plan is empty. Tested by state replay in tasks 8.2 (fallback if the first plan unexpectedly touches members: keep `ignore_changes` and only add the flag).

The module's own `external_membership` input is removed (breaking 7): the lists being empty already means "the module manages no member". Alternative rejected: keep the input as a switch ignoring the lists; it is a second way to express emptiness and exempted three validations.

Membership keys are unchanged (no `moved`): `<group>-app-<key>`, `<group>-user-<8 chars>`. A key scheme on the full user ID would be cleaner but `moved` blocks cannot be generated for dynamic keys, so every membership would be destroyed and re-created (a window without access). New `user_keys` entries use `<group>-user-key-<key>`, distinct from the 8-hex-character form because a hyphen never appears in it. Both kinds share `scaleway_iam_group_membership.users`; the resource sets `user_id = each.value.user_key != null ? scaleway_iam_user.this[each.value.user_key].id : each.value.user_id`.

`user_keys` fixes the real gap: a user invited by the module has an ID known only after apply, so `user_ids` could not reference it in the same call (a module cannot read its own outputs). Reference by key resolves at plan time through the `users` map.

### 3. Policies
Provider (`policy.go`): `user_id`, `group_id`, `application_id`, `no_principal` are `ExactlyOneOf`, so the provider already rejects zero or several. The module's lists with first-wins semantics hid that. New inputs `user_id`, `group_key`, `application_key` (`optional(string)`) and `no_principal`; a validation requires exactly one set (`length(compact(...)) + (no_principal ? 1 : 0) == 1`) with a plan-time module message instead of a provider message; key validations apply to the single entry. The resource becomes:

```
user_id        = each.value.user_id
group_id       = each.value.group_key != null ? scaleway_iam_group.this[each.value.group_key].id : null
application_id = each.value.application_key != null ? scaleway_iam_application.this[each.value.application_key].id : null
no_principal   = each.value.no_principal ? true : null
```

Rule block: `organization_id = rule.value.organization_wide ? var.organization_id : null`, `project_ids = rule.value.project_ids`, `condition = rule.value.condition`, `permission_set_names` unchanged. Provider says "Only one of project_ids and organization_id may be set": a validation rejects `organization_wide` with `project_ids`. "Neither" is left to the provider/API (unverified; task 8.3 checks it against a real organization and the validation is tightened only if the API rejects it). `condition` (CEL, string, optional) is the 2.89.0 `rule.condition`; the module does not parse it (the language belongs to the API), and the `policies` description shows `request.ip in [...]` style examples, as documented by Scaleway.

Perpetual diff: `condition` is read back as sent; `null` is omitted. `organization_id` on the rule equals the policy's `organization_id`, the same value the old input carried. The existing permission-set scope check stays in the provider (proposal, rejected).

Alternative rejected: one policy per principal (fan-out) to keep list inputs: more resources, ambiguous keys; a policy has one principal by API design.

### 4. API key secrets and state
`secret_id` (2.88.0) keeps the secret key out of state; `secret_key` is a computed sensitive attribute otherwise. Options considered for improving state further:
- Ephemeral `scaleway_iam_api_key` (2.89.0; `srn` in unpublished 2.90.0): rejected. It is created on every run, "not stored in Terraform state and not managed by Terraform after creation", deleted on close or left for `expires_at`; it fits creating a credential that feeds another provider or a write-only argument in the same run, not durable keys with outputs. A module output would have to be `ephemeral = true`, unusable as a stored value, which breaks the module's purpose (identity inventory). The managed resource with `secret_id` already achieves "not in state" with the secret held in Secret Manager.
- `*_wo` arguments: `iam_api_key` has none; `iam_user.password_wo` rejected (invitation workflow).
- Default flip: `require_api_key_secret_id = true` (breaking 11). The precondition fails the plan (no state change, no replacement) and offers two exits: `secret_id` (key replacement, a rotation, per key) or `false` (explicit opt-out). `terraform-security` / `quality-security`: safe default, no secret in state, nothing weakened silently. The input keeps its non-`enable_` name (DEVIATION(terraform-variables), already recorded).
- Output split (breaking 8): `api_keys` loses `secret_key` and `sensitive`; the access key and ID become readable without suppression, which makes `api_key_access_keys` and `api_key_ids` redundant. `api_key_secret_keys` is sensitive and holds only keys without `secret_id` (`{for k, v in ... : k => v.secret_key if v.secret_id == null}`). The sensitive-output count stays two.

`expires_at` is ForceNew in the provider and DiffSuppress'd for RFC3339 equivalence; the validation adds `can(timecmp(v, v))` to the existing `Z`-form regex (rejects impossible dates, `timecmp` is available since OpenTofu 1.5 / Terraform 1.3) so a rejected value never reaches the API. No change to what is sent.

### 5. Outputs
From 20 to 14. Removed: `project_id` and `summary` (echo inputs or `length()`), `api_key_access_keys`, `api_key_ids`, `ssh_key_ids`, `ssh_key_fingerprints`, `ssh_key_public_keys` (values already in `api_keys` / `ssh_keys`, or the caller's own input). Kept: `*_ids` for applications, groups, policies and users, which other modules consume as flat maps. `users` gains `mfa` and `locked` (computed on `iam_user`), `security_audit` gains `users_without_mfa` and renames `api_keys_expiring_soon` (misleading: lists every key with `expires_at`) to `api_keys_with_expiration`. `srn` stays unexposed (`terraform-outputs`: not every attribute).

### 6. SSH public key regex
`^ssh-(rsa|ed25519|ecdsa)` rejects real ECDSA keys (`ecdsa-sha2-nistp256 ...`) and accepts the non-existent `ssh-ecdsa`. New: `^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp(256|384|521))\s+[A-Za-z0-9+/=]+`. The accepted ECDSA types are the OpenSSH names; whether the Scaleway API accepts all three is checked in task 8.4.

### 7. Version constraints
`versions.tf` is unchanged: `scaleway/scaleway ~> 2.89` (accepts 2.90.0 once published, whose only module-relevant item is `srn` on the ephemeral key, rejected above). `required_version` stays `>= 1.10.7`: no write-only argument, ephemeral variable or resource is used; `timecmp` and `terraform_data` are older than 1.10.

### 8. Unchanged on purpose
Deletion guards (`terraform_data`, applications/groups/policies, `depends_on` kept: it orders the guard before the protected resource on destroy), the `disabled` SSH key two-step (API limitation, re-verified in task 8.4), `require_api_key_expiration` default `false`, `tags` merging, the `this` labels and every resource address. No `moved` block is needed.

## Migration Plan

1. Pin `?ref=v3.0.0`, apply the README "Upgrading from v2 to v3" edits (`project_name` to `project_id`, principals to scalars, rule scope, `external_membership` removal, output renames, `require_api_key_secret_id`).
2. Plan: expected changes are one in-place update per group (flag), one per API key without `default_project_id` only when `project_id` is set, none otherwise. Apply; the second plan is empty.
3. Optional per key: `secret_id` (replacement, rotation), then drop the opt-out.
Rollback: pin `v2.0.0` and restore the previous inputs; groups flip back in place.

## Risks / Trade-offs

- Many breaking edits in one major: the README section lists each with its edit; the commit body repeats them.
- `external_membership` behaviour at first plan (state still holding member IDs): mitigated by state replay (8.2) with a documented fallback.
- Default `require_api_key_secret_id = true` blocks plans of existing deployments until they choose: intended, single-line opt-out.
- `organization_wide` hides the org ID: the module's `organization_id` is the only valid value (policies cannot grant on other organizations), so nothing is lost.
- Mock-provider tests cannot prove API behaviour (no-neither-scope, ECDSA, disabled key, secret absent from state): real-account group in tasks, not run by the planning step.
