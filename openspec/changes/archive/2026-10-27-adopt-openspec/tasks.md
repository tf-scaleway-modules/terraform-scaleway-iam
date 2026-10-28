## 1. Configuration

- [x] 1.1 Fill `openspec/config.yaml` `context`, rules and operations with scaleway-iam facts (git-cliff CHANGELOG, `tofu test`, no `tests/` yet)
- [x] 1.2 Fill `AGENTS.md` (project, module-specific rules, commands)

## 2. Baseline specs

- [x] 2.1 Write delta specs for `module-contract`, `applications-and-api-keys`, `groups`, `policies`, `users-and-ssh-keys`, `deletion-protection`
- [x] 2.2 Write `proposal.md` and `design.md`

## 3. Documentation

- [x] 3.1 Add the OpenSpec paragraph and `mise run spec-setup` / `mise run spec-validate` steps to the README "Contributing" section

## 4. Validation

- [x] 4.1 `openspec validate --all --strict` passes (same command as the `validate:specs` CI job)
- [x] 4.2 `pre-commit run` passes on the changed files
- [x] 4.3 Archive the change so the main specs land in `openspec/specs/`
