# deletion-protection Specification

## Purpose
`terraform_data` guards that block destruction of applications, groups and policies while `enable_deletion_protection` is true.

## Requirements

### Requirement: Deletion guards
When `enable_deletion_protection` is `true` (default), the module SHALL create one `terraform_data` guard with `prevent_destroy = true` for each application, group and policy, keyed like the resource it protects. The guards SHALL depend on the resource they protect. Destroying a guard MUST fail the plan.

#### Scenario: Guards created by default
- **WHEN** one application, one group and one policy are declared and `enable_deletion_protection` is not set
- **THEN** one guard exists for each of them

#### Scenario: Guard names
- **WHEN** protection is enabled
- **THEN** the guards are `terraform_data.application_deletion_protection`, `terraform_data.group_deletion_protection` and `terraform_data.policy_deletion_protection`

#### Scenario: Destroy blocked
- **WHEN** protection is enabled and a plan would destroy a guard
- **THEN** the plan fails because of `prevent_destroy`

#### Scenario: Protection disabled at creation
- **WHEN** `enable_deletion_protection = false`
- **THEN** no guard is planned

### Requirement: Unguarded resources
API keys, users, SSH keys and memberships SHALL NOT be guarded.

#### Scenario: Removing an unguarded resource
- **WHEN** an API key, a user or an SSH key is removed with protection enabled
- **THEN** no guard blocks the removal
