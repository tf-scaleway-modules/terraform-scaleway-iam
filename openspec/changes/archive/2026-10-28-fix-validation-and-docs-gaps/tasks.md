# Tasks

## 1. Code
- [x] 1.1 `main.tf`: drop `prevent_destroy = false` and its comments (applications, groups, policies); fix the section comments on lifecycle protection
- [x] 1.2 `variables.tf`: validations for `api_keys` (unknown application), `groups` (unknown applications, user ID prefix collision, both skipping `external_membership`), `policies` (selected group and application exist), `ssh_keys` (project required)
- [x] 1.3 `locals.tf` and `main.tf`/`variables.tf`: `policies_with_ignored_principals` local and `check "policy_single_principal"`

## 2. Documentation
- [x] 2.1 `variables.tf` descriptions: `tags`, `enable_deletion_protection`, `require_api_key_expiration`, `policies` (single principal, fixed example)
- [x] 2.2 `outputs.tf`: `users` description and comment, `security_audit` description
- [x] 2.3 README: "Deletion protection" and policy single-principal notes outside the terraform-docs block

## 3. Tests
- [x] 3.1 `tests/main.tftest.hcl`: mock provider, happy path, guards on/off, one rejected-input run per new validation, one run for the check, non-breaking runs (external membership, unused unknown entry)
- [x] 3.2 `examples/complete` and `examples/minimal` still validate (no input change)

## 4. Verification
- [x] 4.1 `tofu fmt -recursive`, `tofu init -backend=false`, `tofu validate`, `tofu test`
- [x] 4.2 `tflint --recursive`, `pre-commit run -a` (regenerates the README terraform-docs block)
- [x] 4.3 `openspec validate fix-validation-and-docs-gaps --strict`, archive, `openspec validate --all --strict`
- [x] 4.4 Commit subject reads as a CHANGELOG line (see the report; the commit is made by the caller)
