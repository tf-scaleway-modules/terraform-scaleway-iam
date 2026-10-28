# deletion-protection Specification

## Purpose
`terraform_data` guards that block destruction of applications, groups and policies while `enable_deletion_protection` is true.

## Requirements

### Requirement: Deletion guards
When `enable_deletion_protection` is `true` (default), the module SHALL create one `terraform_data` guard with `prevent_destroy = true` for each application, group and policy, keyed like the resource it protects. The guards SHALL depend on the resource they protect. Destroying a guard MUST fail the plan. The protected resources themselves SHALL NOT set `prevent_destroy`.

#### Scenario: Guards created by default
- **WHEN** one application, one group and one policy are declared and `enable_deletion_protection` is not set
- **THEN** one guard exists for each of them

#### Scenario: Guard names
- **WHEN** protection is enabled
- **THEN** the guards are `terraform_data.application_deletion_protection`, `terraform_data.group_deletion_protection` and `terraform_data.policy_deletion_protection`

#### Scenario: Destroy blocked
- **WHEN** protection is enabled and a plan would destroy a guard
- **THEN** the plan fails because of `prevent_destroy`

#### Scenario: Entry removed or module destroyed
- **WHEN** protection is enabled and a protected entry is removed from its map, or `tofu destroy` runs
- **THEN** the plan fails because it would destroy a guard

#### Scenario: Flag switched off on an existing deployment
- **WHEN** the guards exist in state and `enable_deletion_protection` is set to `false`
- **THEN** the plan fails because it would destroy the guards

#### Scenario: Protection disabled at creation
- **WHEN** `enable_deletion_protection = false`
- **THEN** no guard is planned

### Requirement: Unguarded resources
API keys, users, SSH keys and memberships SHALL NOT be guarded.

#### Scenario: Removing an unguarded resource
- **WHEN** an API key, a user or an SSH key is removed with protection enabled
- **THEN** no guard blocks the removal

### Requirement: Lifting protection is documented
The `enable_deletion_protection` description and the README SHALL state what the guards block and the sequence that lifts protection: remove the guards from state with `tofu state rm` (`terraform_data.application_deletion_protection`, `terraform_data.group_deletion_protection`, `terraform_data.policy_deletion_protection`, or one `["key"]` instance), then destroy or remove the entry. They SHALL NOT tell users that setting the flag to `false` is enough on an existing deployment.

#### Scenario: Removing one protected application
- **WHEN** a user removes the `ci` application from `applications`
- **THEN** the documentation tells them to run `tofu state rm` on `terraform_data.application_deletion_protection["ci"]` first
