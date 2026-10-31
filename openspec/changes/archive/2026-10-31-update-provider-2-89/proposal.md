## Why

The module still keeps every API key `secret_key` in the Terraform state. Provider 2.88.0 added `secret_id` to `scaleway_iam_api_key`: the secret key is then written as a new version of a Secret Manager secret and never stored in state. This is the one provider change since 2.86 that improves the module's security posture (`terraform-security`: keep secret material out of state; `quality-security`: no secret in state). Provider 2.89.0 also rejects policy rules that mix permission sets of different scopes, which the module should document.

## What Changes

Gap analysis of provider 2.89.0 against the seven resources and one data source the module uses (`iam_api_key`, `iam_application`, `iam_group`, `iam_group_membership`, `iam_policy`, `iam_user`, `iam_ssh_key`, `account_project`): between 2.86.0 and 2.89.0 only `iam_api_key` gained an argument (`secret_id`, 2.88.0) and only `iam_policy` changed behavior (2.89.0 scope check, documentation fix in the docs).

Adopted:

1. **`api_keys[*].secret_id`** (new optional attribute, provider 2.88.0): ID (UUID or `region/UUID`) of an existing Secret Manager secret. When set, the provider stores the `secret_key` as a new secret version and keeps it out of state. The module does not create the secret (see design: the secret belongs to the caller or to `scaleway-secrets-and-keys`). Validated as a UUID or regional ID.
2. **`api_keys` output**: `secret_key` is `null` for a key that sets `secret_id` (the shape is unchanged; the secret is read from Secret Manager, for example with the `scaleway_secret_version` ephemeral resource).
3. **`require_api_key_secret_id`** (new `bool`, default `false`): when `true`, a key without `secret_id` fails the plan through a precondition, mirroring `require_api_key_expiration`. Default `false` keeps every current configuration valid.
4. **`security_audit.api_keys_secret_in_state`** (new key of an existing output): input keys of API keys whose `secret_key` lands in state (those without `secret_id`).
5. **Provider floor `~> 2.89`** in `versions.tf` and both examples: `secret_id` needs 2.88.0; 2.89.0 is chosen so the floor equals the tested version and includes the policy scope validation (design explains why not `~> 2.88`).
6. **Docs**: `policies` description and README state that every rule must use permission sets of one scope (provider 2.89.0 rejects mixes); README upgrade notes and a "What lands in state" table in a new `SECURITY.md`.

Deferred or rejected (reason in one line each, details in design):

- Module-side validation of permission-set scope homogeneity: needs the live permission-set catalogue; the provider already checks it at plan time.
- Rule `condition` on policies, `first_name`/`last_name`/`phone_number`/`locale`/`password_wo` on users, `srn` outputs, `iam_saml`, permission-set data sources, ephemeral `iam_api_key`: no demand, PII or other-module scope, or a larger contract change for little value.
- Creating the Secret Manager secret inside this module: a new resource family and region/project inputs; the sibling module owns secrets.
- Making `secret_id` the default or removing `secret_key` from the output: breaking, and replaces existing keys.

### Semver

**Major.** The provider floor is raised from `~> 2.86` to `~> 2.89` to use `secret_id` (introduced in 2.88.0): a raised floor is major per `terraform-versioning`, and the CHANGELOG line must say so with the reason. Without the floor change this would be minor (new optional attribute, new optional input with default, new output key).

Inputs and outputs whose type, default or meaning changes:

| Item | Change | Existing configuration |
|------|--------|------------------------|
| `api_keys[*].secret_id` | new optional attribute, default `null` | unchanged |
| `require_api_key_secret_id` | new input, default `false` | unchanged |
| `api_keys` output `secret_key` | `null` when `secret_id` is set; unchanged otherwise | unchanged |
| `security_audit` output | new key `api_keys_secret_in_state` | unchanged keys |
| `policies` and `api_keys` descriptions | wording | none |

No default changes, no renamed resource address (no `moved` block), no removed input or output.

### State and security

- Keys without `secret_id` (default): `secret_key` stays in state as today; `SECURITY.md` (new) lists it with the mitigation (use `secret_id`, encrypt and restrict state).
- Keys with `secret_id`: `secret_key` is absent from state and plan. The input carries no secret: `secret_id` is an identifier, so no write-only argument or `*_wo_version` is needed (`terraform-security` applies to secret-bearing inputs; none is added).
- `secret_id` is `ForceNew` in the provider: setting it on an existing key replaces the key (new access key and secret, old key revoked). This is a rotation, documented in the upgrade notes.
- The identity running Terraform needs permission to create secret versions on the target secret (`SecretManagerEditor` on the secret's project); documented in `SECURITY.md` (`terraform-security`: least privilege).

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `applications-and-api-keys`: `secret_id` attribute and validation, `secret_key` output behavior, mandatory secret storage option.
- `module-contract`: provider floor `~> 2.89`, the new input default, sensitive-output wording, `security_audit` key.
- `policies`: single permission-set scope per rule is documented.

## Impact

- Modified: `versions.tf`, `variables.tf` (`api_keys`, new `require_api_key_secret_id`, `policies` description), `main.tf` (`secret_id`, precondition), `outputs.tf` (`api_keys` description, `security_audit`), `examples/minimal/versions.tf`, `examples/complete/versions.tf`, `examples/complete/main.tf`, `tests/main.tftest.hcl`, `README.md` (upgrade notes, regenerated terraform-docs block), new `SECURITY.md`.
- Consumers: none broken at runtime; the provider constraint now excludes 2.86 and 2.87 in their lock files (`tofu init -upgrade`). Pin the module tag `vX+1.0.0`.
- Not run: any apply against a real Scaleway organization (unit tests use a mock provider).
