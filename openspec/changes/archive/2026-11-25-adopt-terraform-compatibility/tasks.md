## 1. Core floor and standards reference

- [x] 1.1 `versions.tf`: set `required_version = ">= 1.11.0"` and drop the "Open tofu 1.10.7" comment; keep one constraint, no `.tofu` file, no `language {}` (`terraform-providers`)
- [x] 1.2 `examples/minimal/versions.tf` and `examples/complete/versions.tf`: `required_version = ">= 1.11.0"`; keep provider `~> 2.89` equal to the root
- [x] 1.3 `openspec/config.yaml`: `terraform` store `ref: v2.1.0` (leave `quality` and `repository` refs); update the "required_version >= 1.10.7" line in `context`

## 2. Toolchain and CI

- [x] 2.1 `mise.toml`: `opentofu = '1.13.10'`, add `terraform = '1.17.2'`; run `mise install`
- [x] 2.2 `.gitlab/release.yml`: `validate:opentofu` image `ghcr.io/opentofu/opentofu:1.13.10`; add `validate:terraform` (`hashicorp/terraform:1.17.2`, init/validate root and each example) right after it; add it to `create:release` `needs:` after `validate:opentofu`
- [x] 2.3 `.pre-commit-config.yaml`: add `args: [--hook-config=--tf-path=tofu]` to `terraform_fmt`, `terraform_docs`, `terraform_tflint`
- [x] 2.4 `.github/workflows/ci.yml` and `release.yml`: `tofu_version` to `1.13.10` (no new job)

## 3. Docs (never between BEGIN_TF_DOCS and END_TF_DOCS)

- [x] 3.1 `README.md`: prerequisites "OpenTofu >= 1.11.0 or Terraform >= 1.11.0"; fix the Terraform badge (`%3E%3D1.10`); add the upgrade note "consumers need OpenTofu or Terraform >= 1.11.0" (stale-wording fix in the v2-to-v3 section only if it misstates the current floor)
- [x] 3.2 `AGENTS.md`: name OpenTofu >= 1.11.0 and Terraform >= 1.11.0; Commands line gains `terraform init -backend=false && terraform validate`
- [x] 3.3 Grep for stale `1.10.0`, `1.10.7`, `1.11.6`, `v1.2.6` outside CHANGELOG.md and the archive; fix prose referring to the old floor or pins

## 4. Verification (each result reported as-is)

- [x] 4.1 `mise exec -- tofu fmt -recursive -check`
- [x] 4.2 `mise exec -- tofu init -backend=false -upgrade && mise exec -- tofu validate` in the root and each `examples/*`
- [x] 4.3 `mise exec -- tflint --init && mise exec -- tflint --recursive`
- [x] 4.4 `mise exec -- tofu test`
- [x] 4.5 Terraform compatibility in a scratch copy (rsync excluding `.terraform`, lock files, `.git`, `mise*.toml`; run `$(mise which terraform)` init/validate in root and each example); never in the repo
- [x] 4.6 `mise exec -- openspec validate --all --strict`
- [x] 4.7 `mise exec -- pre-commit run -a` with every `.terraform.lock.hcl` moved outside the repo, restored afterwards

## 5. Commit (apply wave)

- [x] 5.1 One signed commit (`git commit -S`), imperative subject reading as a CHANGELOG line without `feat:` prefix, e.g. "Require OpenTofu or Terraform 1.11.0 and validate with both"; body: `BREAKING:` plus "consumers need OpenTofu or Terraform >= 1.11.0". Do not edit CHANGELOG.md.
