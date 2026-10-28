## Context

The module is released and used by consumers pinning `?ref=vX.Y.Z`. It has no spec history. The goal is to adopt the shared OpenSpec workflow without touching the module contract, so every decision below is about tooling and documentation.

## Goals / Non-Goals

**Goals:**
- Same OpenSpec setup as the other Leminnov modules, validated locally and in CI.
- A baseline contract that is true to the released code.

**Non-Goals:**
- Any change to `*.tf`, `examples/`, inputs, outputs, resources or state.
- Adding unit tests: no `tests/` directory exists; the first behaviour change adds `tests/main.tftest.hcl`.
- Fixing the inconsistencies found while reading the code; they are reported, not specified as intended behaviour.

## Decisions

- **Stores pinned through the profile.** `openspec/config.yaml` and `AGENTS.md` are copies of the `terraform-module` profile; `references:` (`quality`, `repository`, `terraform`) keep the profile's tags. `mise run spec-setup` registers the stores once per machine.
- **Skills for both agents.** The `openspec-*` skills are installed under `.claude/skills/` (Claude Code) and `.opencode/skills/` (OpenCode, which reads `AGENTS.md` natively); `CLAUDE.md` imports `AGENTS.md`.
- **CI job `validate:specs`.** `.gitlab/specs.yml` runs `openspec validate --all --strict` with `OPENSPEC_VERSION` from `.gitlab/global.yml`; it needs no store.
- **CHANGELOG via git-cliff kept.** `CHANGELOG.md` is generated from commit subjects (`mise run changelog`, `.cliff.toml`). The profile's "curated under `## [Unreleased]`" rules are rewritten to "commit subjects read as CHANGELOG lines".
- **Test commands.** No `mise run test`, `scan` or `test-integration` task exists; unit tests are `tofu test`, only meaningful once `tests/` exists.
- **Capability split.** Six capabilities follow the resource families in `main.tf`: `module-contract` (versions, inputs, outputs), `applications-and-api-keys` (credentials are the sensitive part), `groups` (with membership flattening in `locals.tf`), `policies` (principal selection and rules), `users-and-ssh-keys` (identities and project-scoped keys) and `deletion-protection` (cross-cutting `terraform_data` guards).
- **Baseline describes current behaviour, quirks included.** Where the code is clear but surprising (a policy uses only the first principal of the highest-priority list, `security_audit.api_keys_expiring_soon` lists every key with an expiry), the spec states what the code does. Behaviour that is unclear or looks unintended (see the report of this change) is left out.

## Risks / Trade-offs

- A spec that encodes a quirk can be read as an endorsement. Mitigation: later changes modify these requirements explicitly through delta specs.
- No unit tests back the baseline scenarios yet. Mitigation: scenarios are written from the code; the first behaviour change adds `tests/main.tftest.hcl`.
