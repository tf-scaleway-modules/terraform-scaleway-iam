## Context

The `terraform` store v2.1.0 raises the core floor to `>= 1.11.0` for both OpenTofu and Terraform and adds a Terraform validation job and pinned toolchain. This module is at `>= 1.10.7`, OpenTofu-only in CI, and its pre-commit Terraform hooks carry no `--tf-path`.

## Goals / Non-Goals

**Goals:** align `required_version`, toolchain pins, CI and docs with v2.1.0; prove the module validates under both CLIs.

**Non-Goals:** any input, output, resource or provider change; bumping the provider (`~> 2.89` stays); changing the `terraform_data` deletion guards (`prevent_destroy` with a variable is OpenTofu-only, forbidden by the standard); adding the other hooks of `terraform-repo-precommit` (`terraform_validate`, checkov, trivy) or moving the hook `rev`: outside this change.

## Decisions

- **One constraint** `required_version = ">= 1.11.0"` in `versions.tf` and both examples; no `.tofu` file, no `language {}` block (`terraform-providers`). The stale trailing comment "Open tofu 1.10.7" is dropped. Example floors (`>= 1.10`) are aligned to the root.
- **Provider**: examples already use `~> 2.89`, equal to the root; no change. No new provider argument is used, so no provider floor changes.
- **Toolchain**: `opentofu = '1.13.10'`, `terraform = '1.17.2'`, both exact (`terraform-repo-mise`). The `validate:terraform` image tag equals the `mise.toml` pin.
- **CI**: `validate:terraform` has the same shape as `validate:opentofu` (init with `-backend=false`, validate, loop over `examples/*/`), placed right after it and added to `create:release` `needs:` (`terraform-repo-gitlab-ci`). It has no `cache:` on `.terraform` so a tofu-initialised directory is never reused by terraform.
- **GitHub workflows**: `tofu_version` becomes `1.13.10` in `ci.yml` and `release.yml`; they have no Terraform step, so nothing else changes.
- **Pre-commit**: add `args: [--hook-config=--tf-path=tofu]` to `terraform_fmt`, `terraform_docs`, `terraform_tflint` so hooks keep running OpenTofu now that both CLIs are installed.
- **Spec**: MODIFIED delta on `module-contract` because it states the floor; no other repo spec mentions the floor, toolchain or CI jobs.
- **Release**: major, per `terraform-versioning` (raised `required_version`); the commit body carries `BREAKING:` and the upgrade note; the README gets the upgrade note.

## Risks / Trade-offs

- Consumers on 1.10.x are blocked until they upgrade: accepted, announced as major.
- No perpetual diff or state migration: no resource changes, a second plan stays empty.
- The GitHub mirror workflows pin `tofu_version: "1.11.0"`; they follow the `mise.toml` pin (`1.13.10`, `terraform-repo-mise` "Hooks and CI use the pinned tools"). No GitHub job is added.

## Open Questions

None.
