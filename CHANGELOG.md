# Changelog

All notable changes to this project will be documented in this file.

## [4.0.0] - 2026-11-25
- Require OpenTofu or Terraform 1.11.0 and validate with both

BREAKING: required_version is raised from >= 1.10.7 to >= 1.11.0. Consumers
need OpenTofu or Terraform >= 1.11.0.

Pin opentofu 1.13.10 and terraform 1.17.2 in mise.toml, add a
validate:terraform CI job, align the GitHub workflows, keep the pre-commit
Terraform hooks on tofu and adopt terraform standards v2.1.0.
- Regenerate the README input and output tables with terraform-docs
- Rewrite input and output descriptions as single-line prose so they render on the Terraform Registry
## [3.0.0] - 2026-11-01
- Use project_id, one principal per policy, policy conditions, group user_keys and secret_id by default

BREAKING: v3.0.0.

- project_name is replaced by project_id (UUID, null = provider default);
  SSH keys and API key default projects fall back to it.
- Policies take one principal (user_id, group_key, application_key or
  no_principal); rules use organization_wide instead of organization_id
  and accept a condition.
- groups lose external_membership (always declared to the provider) and
  gain user_keys to add module-created users in the same apply.
- require_api_key_secret_id defaults to true.
- api_keys is no longer sensitive and has no secret_key: use
  api_key_secret_keys. Outputs project_id, summary, api_key_access_keys,
  api_key_ids, ssh_key_ids, ssh_key_fingerprints and ssh_key_public_keys
  are removed; security_audit.api_keys_expiring_soon becomes
  api_keys_with_expiration and gains users_without_mfa; users expose mfa
  and locked.
- expires_at must be a real date; SSH keys must use a real key type prefix.

See "Upgrading from v2 to v3" in the README.
## [2.0.0] - 2026-10-31
- Store API key secrets in Secret Manager with secret_id and require Scaleway provider ~> 2.89

BREAKING: the module now requires the scaleway/scaleway provider ~> 2.89
(was ~> 2.86).

- api_keys[*].secret_id sends the API key secret key to an existing Secret
  Manager secret; secret_key is then null and kept out of state and outputs
- require_api_key_secret_id fails the plan for keys without secret_id
- security_audit.api_keys_secret_in_state lists keys still stored in state
- document single-scope policy rules (checked by the provider) and add
  SECURITY.md

Upgrade notes: bump the tag and run `tofu init -upgrade`; existing keys plan
no change. Adding secret_id to an existing key replaces it (rotation), so
adopt it per key and update consumers of the access key.
## [1.2.2] - 2026-10-28
- Fix IAM reference validation and correct deletion protection docs

- Validate unknown application and group references, user ID prefix collisions in a group and SSH keys without a project at plan time.
- Warn with a check when a policy lists principals that are ignored.
- Correct the deletion protection docs: setting the flag to false on an existing deployment is blocked by the guards, so lift protection with tofu state rm.
- Fix the tags, users, security_audit and require_api_key_expiration descriptions and drop the no-op prevent_destroy = false.
- Add the first unit tests.
No upgrade action needed: the new validations reject only configurations that already failed.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
## [1.2.1] - 2026-10-28
- Key the pre-commit cache on mise.toml and .pre-commit-config.yaml

The cache was keyed on the branch, so a branch kept tools installed by the previous mise, which the new one no longer puts on PATH (tofu not found). Keying it on the files that define the toolchain, as in scaleway-compute and scaleway-storage, starts a fresh cache whenever the toolchain changes and shares it across branches and tags.
- Install mise 2026.10.17 in CI to avoid the GitHub API rate limit

The pre-commit job installed an old mise that resolves every tool through api.github.com without a token, and failed with 403 rate-limit errors on the shared office runner whenever its cache was cold (new refs such as merge requests and tags). mise 2026.9.14 and later resolve releases through mise-versions.jdx.dev.
- Run validate:specs in merge request pipelines

A job without rules: only runs in branch and tag pipelines, so the merge request pipeline did not validate openspec/. rules: when: always matches the other validate jobs.
- Adopt OpenSpec and publish the baseline specs

Planning adopts OpenSpec, aligned with the other leminnov Terraform
modules: the engineering standards come from the quality, repository and
terraform OpenSpec stores. openspec/config.yaml follows the terraform-module profile
(stores pinned at quality v1.2.6, repository v4.1.0, terraform v1.2.6) and
AGENTS.md, imported by CLAUDE.md, routes to them. openspec/specs/ holds the
baseline specification of the module as released, produced by the archived
adopt-openspec change. The openspec-* skills are installed for Claude Code
and OpenCode, openspec 1.14.3 and node are pinned in mise.toml with the
spec-validate and spec-setup tasks, and the validate:specs CI job runs
openspec validate --all --strict. The module contract is unchanged.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
## [1.2.0] - 2026-10-14
- chore(deps): upgrade scaleway provider to ~> 2.86

- Bump the scaleway provider constraint to ~> 2.86 (module and examples).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
- typo
## [1.0.0] - 2025-12-22
- Updates Scaleway provider version

Changes the Scaleway provider version constraint to allow for minor version updates.
- Updates IAM module documentation and examples

Improves documentation for API key expiration and SSH key disabling.

Refactors the complete example to clarify user management and security settings.

Adds development prerequisites and workflow instructions.

Removes 2FA output from non-sensitive users output to avoid confusion.

Updates security audit output to reflect the new SSH key status.
- Updates pre-commit hooks to use local commands

Switches from using a remote pre-commit-terraform repository to using local system commands for formatting and documentation generation.

This change avoids reliance on a specific Terraform version managed by pre-commit-terraform and allows inheriting the PATH environment from mise, ensuring consistent tool versions.

It also configures terraform-docs to inject the documentation into the README.md file.
- first version
- initialisation
- initialisation
- first version
- Initial commit

