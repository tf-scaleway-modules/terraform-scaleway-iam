# Tasks

Fetch `terraform-code-style`, `terraform-variables`, `terraform-outputs` and `terraform-security` (store `terraform`) before editing HCL. Run `tofu fmt -recursive`, `tofu validate` and `tofu test` after each group; run every tool through `mise exec --` from the module root. Do not mark a task done while one fails.

## 1. Project input and lookup removal

- [x] 1.1 `variables.tf`: replace `project_name` by `project_id` (`string`, `default = null`, validation regex lowercase UUID, message "project_id must be a valid UUID format."); delete `data.tf` and `local.project_id`. Verify: `grep -rn "project_name\|scaleway_account_project" --include=*.tf .` finds nothing in the root module.
- [x] 1.2 `main.tf`: SSH key `project_id = each.value.project_id != null ? each.value.project_id : var.project_id`; API key `default_project_id` likewise; delete the `ssh_keys` validation "needs a project_id when project_name is not set". Verify with the runs in 1.3.
- [x] 1.3 `tests/main.tftest.hcl`: remove the `scaleway_account_project` mock; runs for (a) SSH key inheriting `project_id`, (b) own `project_id` wins, (c) no project anywhere plans, (d) API key default project follows `project_id`, (e) rejected `project_id = "my-project"` (`expect_failures = [var.project_id]`). Drop the old `ssh_key_without_project` and `ssh_key_with_own_project_and_no_project_name` runs or rewrite them as (c) and (b).

## 2. API keys and secrets

- [x] 2.1 `variables.tf`: `require_api_key_secret_id` default `true`, description updated (opt-out, replacement on adoption); `expires_at` validation adds `can(timecmp(v.expires_at, v.expires_at))` to the regex. Keep the DEVIATION(terraform-variables) comment.
- [x] 2.2 `main.tf`: delete `depends_on` on `scaleway_iam_api_key.this` (the application reference orders it).
- [x] 2.3 `outputs.tf`: `api_keys` non-sensitive with `id`, `access_key`, `description`, `created_at`, `expires_at`; new sensitive `api_key_secret_keys` (`{for k, v in scaleway_iam_api_key.this : k => v.secret_key if v.secret_id == null}`); delete `api_key_access_keys`, `api_key_ids`; descriptions say where the secret is read.
- [x] 2.4 Tests: default `true` rejects a key without `secret_id` (`expect_failures = [scaleway_iam_api_key.this["k"]]`); `require_api_key_secret_id = false` accepts it and lists it in `security_audit.api_keys_secret_in_state`; `api_keys` output has no `secret_key`; `api_key_secret_keys` excludes keys with `secret_id`; rejected `expires_at = "2026-13-45T00:00:00Z"`; update existing runs that created keys without `secret_id` (set `require_api_key_secret_id = false` or add `secret_id`).

## 3. Groups

- [x] 3.1 `variables.tf` `groups`: remove `external_membership`; add `user_keys = optional(list(string), [])`; validations: `user_keys` are keys of `users` ("Group user_keys must be keys of the users input."), `application_keys` and the user ID prefix validation lose the `external_membership` exemption; description explains that empty lists leave membership to others.
- [x] 3.2 `main.tf`: group sets `external_membership = true`; delete `lifecycle.ignore_changes` and `depends_on`; delete `depends_on` of both membership resources; the `users` membership picks `scaleway_iam_user.this[user_key].id` for `user_keys` entries. `locals.tf`: add the `user_keys` flattening with key `<group>-user-key-<key>`, drop `local.application_ids`, `group_ids`, `user_ids` (outputs compute them).
- [x] 3.3 Tests: group plans `external_membership = true` with no `ignore_changes` needed; membership keys `devs-app-cicd`, `devs-user-12345678`, `devs-user-key-bob`; rejected unknown `user_keys`; rejected application_keys of an unknown application on every group; a group with empty lists creates no membership.

## 4. Policies

- [x] 4.1 `variables.tf` `policies`: replace the three lists by `user_id`, `group_key`, `application_key` (`optional(string)`); rule `organization_id` becomes `organization_wide = optional(bool, false)`; add `condition = optional(string)`; validations: exactly one principal ("Each policy must set exactly one of user_id, group_key, application_key or no_principal = true."), `user_id` UUID, `group_key`/`application_key` exist, `organization_wide` xor `project_ids` ("A rule must not set both organization_wide and project_ids."); description gets a condition example and the single-scope note kept from 2.89.
- [x] 4.2 `main.tf`: simplify the policy resource to the four scalar assignments and the rule block (`organization_id = rule.value.organization_wide ? var.organization_id : null`, `condition`); delete `check "policy_single_principal"`, `local.policies_with_ignored_principals` and the `depends_on`.
- [x] 4.3 Tests: one run per validation (rejected: several principals, none, bad `user_id`, unknown `group_key`, unknown `application_key`, both scopes); accepted: `no_principal` template; `organization_wide` gives the rule `organization_id`; `condition` passed through; permission sets passed through (keep the existing run). Delete the runs of the removed check.

## 5. Users, SSH keys, outputs, cleanup

- [x] 5.1 `variables.tf` `ssh_keys`: `public_key` regex `^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp(256|384|521))\s+[A-Za-z0-9+/=]+` with the new message; description updated for the project fallback.
- [x] 5.2 `outputs.tf`: `users` adds `mfa`, `locked`; `security_audit` renames `api_keys_expiring_soon` to `api_keys_with_expiration` and adds `users_without_mfa`; delete `project_id`, `summary`, `ssh_key_ids`, `ssh_key_fingerprints`, `ssh_key_public_keys`. Result: 14 outputs (`applications`, `application_ids`, `api_keys`, `api_key_secret_keys`, `groups`, `group_ids`, `policies`, `policy_ids`, `users`, `user_ids`, `user_details`, `ssh_keys`, `group_memberships`, `security_audit`); only `api_key_secret_keys` and `user_details` sensitive. Update the header comment blocks of `main.tf`, `variables.tf` and `outputs.tf`.
- [x] 5.3 Tests: `users` output exposes `mfa`/`locked`; `security_audit` lists; ECDSA key accepted; `ssh-ecdsa AAAA` rejected; output names asserted by an `output` reference in each run that touches them.
- [x] 5.4 `versions.tf` unchanged (`>= 1.10.7`, `~> 2.89`); verify no provider/backend block and no leftover `project_name`.

## 6. Examples and docs

- [x] 6.1 `examples/minimal`: variable `project_id` (replaces `project_name`), `secret_id` variable for the key (default requirement), no hard-coded secret.
- [x] 6.2 `examples/complete`: `project_id` variable, drop the project data source from the module call (keep the secret resource), show `user_keys` in a group, a policy with `condition` and `organization_wide`, a rule per scope, `group_key`/`application_key`, one key with `secret_id` and one explicit opt-out documented in a comment; update `outputs.tf` to the 14 outputs.
- [x] 6.3 `README.md` (outside the terraform-docs block): new "Upgrading from v2 to v3" section listing breaking changes 1 to 12 of the proposal each with its consumer edit and the expected first plan; refresh Usage, Architecture, API Key Management and Policy Design sections; `SECURITY.md` "What lands in state" table (secret key in `api_key_secret_keys` only without `secret_id`; emails in `user_details`).
- [x] 6.4 Verify each README example against the specs scenarios; do not edit between `BEGIN_TF_DOCS` / `END_TF_DOCS`.

## 7. Verification (offline)

- [x] 7.1 `mise exec -- tofu fmt -recursive`, `mise exec -- tofu init -backend=false && mise exec -- tofu validate` in the root and both examples, `mise exec -- tflint --recursive`, `mise exec -- tofu test`; report outputs as-is. Delete the generated `.terraform.lock.hcl` and `.terraform/` afterwards.
- [x] 7.2 Move any local `.terraform.lock.hcl` aside (root and examples), then `mise exec -- pre-commit run -a`; verify the terraform-docs block shows `~> 2.89` and the new inputs and outputs.
- [x] 7.3 `mise exec -- openspec validate modernize-provider-2-89 --strict` and `mise exec -- openspec validate --all --strict` pass.
- [x] 7.4 Commit subject (it becomes the CHANGELOG line, `.cliff.toml` prints the message as is): `Use project_id, one principal per policy, policy conditions, group user_keys and secret_id by default` with a body starting `BREAKING:` that lists the renamed or removed inputs and outputs and points to the README upgrade section.

## 8. Real-account checks (NOT part of the unit suite; record run or skipped in the release notes)

- [ ] 8.1 Apply `examples/complete` against a test organization; check the key with `secret_id` has no `secret_key` in state, `api_key_secret_keys` lists only the other key, the second plan is empty, then destroy (lift guards with `tofu state rm`).
- [ ] 8.2 Upgrade replay: apply the v2.0.0 `examples/complete`, switch to the v3 module with the README edits; expect one in-place update per group (flag) and, only with `project_id` set, per API key without `default_project_id`; apply, then the second plan is empty and no membership is destroyed.
- [ ] 8.3 Policy rule with neither `organization_wide` nor `project_ids`: record what the API says; tighten the rule-scope validation only if it is rejected. Policy `condition` with an IP allow-list takes effect.
- [ ] 8.4 SSH keys: an ECDSA `nistp256`, `nistp384` and `nistp521` key is accepted (adjust the regex otherwise); the disabled two-step still holds.
