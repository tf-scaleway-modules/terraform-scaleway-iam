# Tasks

Fetch `terraform-code-style`, `terraform-variables` and `terraform-outputs` (store `terraform`) before editing HCL. Run `tofu fmt -recursive`, `tofu validate` and `tofu test` after each group.

## 1. Provider floor

- [x] 1.1 `versions.tf`: `scaleway/scaleway` `~> 2.86` → `~> 2.89`; same in `examples/minimal/versions.tf` and `examples/complete/versions.tf`. Verify with `grep -rn '~> 2.8' --include=versions.tf .` showing only `~> 2.89`, and `tofu init -backend=false && tofu validate` passing in the root and both examples.

## 2. API key secret storage (code, tests and docs together)

- [x] 2.1 `variables.tf` `api_keys`: add `secret_id = optional(string)`, a validation "secret_id must be a UUID or a regional ID (<region>/<uuid>)." (lowercase UUID with an optional `<region>/` prefix), and document the attribute, the ForceNew replacement and the unmanaged secret in the description (example with `secret_id`). Verify with the rejected-input run in 2.4.
- [x] 2.2 `variables.tf`: add `require_api_key_secret_id` (`description`, `type = bool`, `default = false`, placed next to `require_api_key_expiration`, with a `DEVIATION(terraform-variables)` comment explaining the name follows `require_api_key_expiration`). `main.tf`: pass `secret_id = each.value.secret_id` to `scaleway_iam_api_key.this` and add a `precondition` "API key '${each.key}' must set secret_id when require_api_key_secret_id is enabled." Verify with the runs in 2.4.
- [x] 2.3 `outputs.tf`: extend the `api_keys` description (`secret_key` is `null` when `secret_id` is set; read it from the secret, for example with `scaleway_secret_version`), add `api_keys_secret_in_state` (keys with `secret_id == null`) to `security_audit` and its description. Keep the output shapes otherwise unchanged. Verify with the assertions in 2.4.
- [x] 2.4 `tests/main.tftest.hcl` (`mock_provider "scaleway"`, `command = plan`): (a) key with `secret_id` plans and the existing happy path still plans a key without it; (b) `expect_failures = [var.api_keys]` for `secret_id = "my-secret"`; (c) a regional ID `fr-par/<uuid>` is accepted; (d) `require_api_key_secret_id = true` with a key lacking `secret_id` → `expect_failures = [scaleway_iam_api_key.this["<key>"]]`; (e) `true` with all keys set → succeeds; (f) `security_audit.api_keys_secret_in_state` lists only keys without `secret_id`; (g) `api_keys` output `secret_key` is null for a key with `secret_id` (mock default for the attribute is acceptable only if asserted on `secret_id`; if the mock fills `secret_key`, assert `scaleway_iam_api_key.this["<key>"].secret_id` instead and note it). Verify with `tofu test` passing.
- [x] 2.5 `examples/complete`: add a Secret Manager secret resource (or an input `secret_id` variable without default) and set `secret_id` on one key, leave one key without it, show the `scaleway_secret_version` read in a comment; no literal secret or token. Update `examples/complete/outputs.tf` only if needed. Verify with `tofu init -backend=false && tofu validate` in `examples/complete` and `examples/minimal`.
- [x] 2.6 Create `SECURITY.md` with a "What lands in state" table (`api_keys[*].secret_key` in state unless `secret_id` is set, with mitigation; `user_details` emails) and a least-privilege note (`SecretManagerEditor` on the secret's project for the Terraform identity). Verify the table matches the `api_keys` and `user_details` outputs.

## 3. Policy scope documentation

- [x] 3.1 `variables.tf` `policies` description: all `permission_set_names` of one rule must share a scope (organization or project), the provider (2.89.0) rejects a mixed rule at plan time, split it into two rules. Verify with a test that a rule passes `permission_set_names` through unchanged (extend the happy-path run).
- [x] 3.2 README (outside the terraform-docs block): "Policy Design" note on single-scope rules, "API Key Management" section on `secret_id`, `require_api_key_secret_id`, reading the secret, and the ForceNew replacement; a "What lands in state" pointer to `SECURITY.md`; upgrade notes for the **major** release (provider floor `~> 2.89` and why, `tofu init -upgrade`, no plan change for existing keys, per-key adoption as rotation). Verify by reading the section against the specs scenarios.

## 4. Verification and release

- [x] 4.1 `tofu fmt -recursive`, `tofu init -backend=false && tofu validate`, `tflint --recursive`, `tofu test`; verify all pass and report their output as-is.
- [x] 4.2 Move any local `.terraform.lock.hcl` aside (root and examples) before `pre-commit run -a` and before pushing: a local lock file makes terraform-docs write the locked provider version instead of the constraint in the README. Run `pre-commit run -a`; verify the README terraform-docs block shows `~> 2.89` for the requirement and provider, and the new input/output text.
- [x] 4.3 `openspec validate update-provider-2-89 --strict` passes; after merge archive and run `openspec validate --all --strict`.
- [x] 4.4 Commit subject reads as the CHANGELOG line and says it is breaking, for example `Store API key secrets in Secret Manager with secret_id and require Scaleway provider ~> 2.89`, with `BREAKING:` and upgrade notes in the commit body; no `feat!:` prefix, following the repository's recent subjects (git-cliff generates CHANGELOG.md, do not edit it by hand; the release is a major). Verify with `mise run changelog` output in a scratch review, not committed by hand.
- [ ] 4.5 Real-organization run of `examples/complete` (apply, check that `secret_key` is absent from state for the key with `secret_id`, empty second plan, destroy) is NOT part of the unit suite; record it as run or skipped in the release notes. (skipped: no credentials; not run)

## Workflow follow-up

- Archive the change after review; the archive step updates the `applications-and-api-keys`, `module-contract` and `policies` main specs.
