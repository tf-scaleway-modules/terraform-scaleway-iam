## Context

Current state: `scaleway_iam_api_key.this` (main.tf) passes `application_id`/`user_id`, `description`, `expires_at`, `default_project_id`; the `api_keys` output exposes `secret_key`, so every key secret sits in state. Provider `~> 2.86`, tool `>= 1.10.7`. See proposal.md for motivation, semver and the deferred list. Standards applied: `terraform-versioning`, `terraform-providers` (raised floor names the argument and version), `terraform-security` (no secret in state, guardrails), `terraform-variables` (declaration shape, validation, naming), `terraform-outputs` (stable shapes), `terraform-state`, `terraform-testing`, `quality-security` (no secret in state, safe defaults, no silent weakening).

Provider research (docs of tags v2.86.0 and v2.89.0 diffed for every resource used, plus `internal/services/iam/api_key.go` and `policy.go` at v2.89.0):

| Resource | 2.86.0 → 2.89.0 |
|----------|-----------------|
| `scaleway_iam_api_key` | `secret_id` added (2.88.0); `secret_key` unset when it is used |
| `scaleway_iam_policy` | scope check in `CustomizeDiff` (2.89.0, calls the permission-set API, skipped with a warning if it fails); no schema change |
| `scaleway_iam_application`, `_group`, `_group_membership`, `_user`, `_ssh_key`, `data.scaleway_account_project` | none in the docs (the `srn` attribute of the data source appeared in 2.87.0, not needed) |

## Goals / Non-Goals

**Goals:** let a consumer keep API key secrets out of state with one attribute, let a platform team enforce it, make the remaining exposure visible, keep every current configuration and plan unchanged.

**Non-Goals:** creating Secret Manager secrets, reading them back (ephemeral resources need OpenTofu 1.11 / Terraform 1.10 in the caller; the module itself uses none), changing the default to secret storage, encryption of state.

## Decisions

### 1. `api_keys[*].secret_id` takes an external secret ID (provider 2.88.0)
`scaleway_iam_api_key.secret_id` (Optional, ForceNew, UUID or `region/UUID`, locality-aware diff suppression) is passed straight from `each.value.secret_id`. The module does **not** create the `scaleway_secret`.
- Module boundary: secrets, their path, project, region, KMS key, ephemeral policy and protection are the job of `scaleway-secrets-and-keys`; duplicating them here would add `region`/`project_id` inputs and a second place to manage secrets.
- Alternative rejected: `create_secret = true` per key creating `scaleway_secret.api_key[each.key]`. More resources, inputs and destroy-order concerns (a protected secret blocks destroy) for no gain over wiring the sibling module's `secret_ids` output into `secret_id`.
- Secret versions: each (re)creation of the key adds a version; consumers read the latest one.

Validation (`terraform-variables`, `quality-security` validate at the boundary): `secret_id == null || can(regex("^([a-z]{2}-[a-z]{3}/)?<uuid>$", secret_id))`, message "secret_id must be a UUID or a regional ID (<region>/<uuid>)." The regex is the existing lowercase-UUID pattern with an optional region prefix (`fr-par`, `nl-ams`, `pl-waw`, ...).

### 2. `secret_key` output unchanged in shape
The output expression stays `secret_key = v.secret_key`; with `secret_id` set the provider leaves the attribute unset, so it evaluates to `null`. No key is added or removed (`terraform-outputs`: stable shapes), and consumers that already handle a missing secret are fine. The description is extended with the secret-manager path (how to read: `scaleway_secret_version` ephemeral resource or data source on the secret).

### 3. `require_api_key_secret_id` (bool, default `false`)
Mirrors `require_api_key_expiration`: a `precondition` in the `lifecycle` of the API key, message naming the key. Alternatives: a `check` warning (only warns, so a platform team cannot enforce) and a validation (the existing expiration rule uses a precondition; consistency wins). Default `false` is the compatible choice; secure-by-default would be a breaking default change with key replacement for every existing key, rejected here and listed for a future major. Naming: `terraform-variables` asks for `enable_`/`is_` booleans, but the sibling `require_api_key_expiration` is a released input; the new one follows it for coherence (DEVIATION(terraform-variables) comment in the code).

### 4. `security_audit.api_keys_secret_in_state`
A list of keys with `secret_id == null`, derived from input (like the other audit lists). Additive key in an existing map output: minor-level.

### 5. Provider floor `~> 2.89`
`secret_id` requires 2.88.0, so the strict need-driven floor is `~> 2.88`. `~> 2.89` is chosen because 2.89.0 is the version this change is built and tested against (docs, mock provider schema) and it contains the policy scope validation the new `policies` documentation describes; consumers on 2.88.x gain nothing by staying. The cost is identical for the semver class (any raised floor is major). Examples' `versions.tf` follow. The CHANGELOG line must state the major and the reason.

### 6. Policy scope: document, do not re-implement
Provider 2.89.0 calls the permission-set API in `CustomizeDiff` and fails when one rule mixes permission sets of different scope types. A module check would need `scaleway_iam_permission_sets`-style data (not used by the module) or a hard-coded catalogue that drifts. The provider check is authoritative and plan-time, so the module only documents it (`policies` description, README) and keeps `permission_set_names` untouched. Rule-level "exactly one of `organization_id`/`project_ids`" is also left to the provider: the module cannot be sure which combinations the API accepts, and rejecting a working configuration would be a breaking validation.

### 7. Considered and deferred
- `scaleway_iam_policy.rule.condition`, `scaleway_iam_user` `first_name`/`last_name`/`phone_number`/`locale`/`password_wo`: exist before 2.86, optional, no current demand; users are invitations (the person sets their own credentials) so no secret is needed. Each is an additive minor change if requested.
- `srn` attributes (all IAM resources): not needed by any output; `terraform-outputs` says not to export every attribute.
- `scaleway_iam_api_key` ephemeral resource (delete-on-close default changed in 2.88.0): the module uses no ephemeral resource.
- `scaleway_iam_saml`, permission-set/other data sources: out of the module's scope (resources for one organization's identities).
- `group.external_membership`: already exposed.

## Perpetual diff and state migration

- Keys without `secret_id`: argument `null`, state attribute absent → no diff; the second plan is empty. `require_api_key_secret_id = false` plans nothing.
- Keys with `secret_id`: `secret_key` is not written to state and is not read back, so no drift. A regional ID and the bare UUID of the same secret do not diff (provider locality suppression); tests/examples use the same form consistently.
- Existing deployments: upgrading the module only changes the constraint and adds `null` arguments: in-place no-op, no `moved` block, no replacement. Adopting storage on an existing key is **ForceNew**: the key is replaced (new access key and secret, the old key is revoked). Treat it as a rotation: do it per key, update consumers of `access_key`, and read the new secret from Secret Manager. No state surgery is needed; the old `secret_key` disappears from state when the key is replaced.
- `tofu init -upgrade` is required where the lock file pins 2.86 to 2.88 (documented).

## Security

`secret_id` is an identifier, not a secret, so no `*_wo` argument, `ephemeral` input or `*_wo_version` applies. State now holds the API key secret only for keys without `secret_id`; `SECURITY.md` (created by this change, nonexistent so far) has a "What lands in state" table with `api_keys[*].secret_key` and the mitigation, `user_details` (emails, sensitive output) and the least-privilege note: the identity running Terraform needs `SecretManagerEditor` (create versions) on the target secret's project. No security control is weakened (`quality-security`: no silent weakening); nothing in the module shells out to a CLI and no `provider {}`/`backend {}` is added.

## Risks / Trade-offs

- Major bump for an opt-in feature → documented in the CHANGELOG subject and README upgrade note; the floor is the only breaking element.
- Replacement of a key when `secret_id` is added → documented as rotation, per-key adoption.
- Secret must exist before the key (create-order) → the caller passes `secret_id` from the resource/module output, which Terraform orders; an unknown value at plan time is fine.
- Caller needs Secret Manager permission and a reachable region → `SECURITY.md`; a regional ID avoids relying on the provider default region.
- A new `bool` input not named `enable_*` → consistency with `require_api_key_expiration`, flagged with DEVIATION.
- Mock-provider tests cannot prove `secret_key` is absent from real state → covered by the example run against a real organization before release (`terraform-testing`: examples as tests); recorded as not run by the planning step.

## Migration Plan

1. Release as a new major; README upgrade note: bump the tag, run `tofu init -upgrade`, plan shows no change.
2. Optional per key: create or reuse a secret (for example with `scaleway-secrets-and-keys`), set `secret_id`, accept the key replacement, read the new secret from Secret Manager.
3. Optional: set `require_api_key_secret_id = true` once every key has a `secret_id`.
Rollback: remove `secret_id` (another replacement; the secret keeps its old versions) and pin the previous tag with provider `~> 2.86`.

## Implementation notes

- Mock provider: the planned `secret_key` is a computed attribute, so the unit tests assert `scaleway_iam_api_key.this["<key>"].secret_id` and the `security_audit` list instead of a null `secret_key` (task 2.4 g). Absence from real state stays covered by the real-organization example run (task 4.5, not run).
- `security_audit.api_keys_secret_in_state` reads `secret_id` from the planned resources, like the other audit lists.
- `examples/complete` creates a `scaleway_secret` and wires its ID into `terraform_key`; the other keys keep storing the secret key in state.
