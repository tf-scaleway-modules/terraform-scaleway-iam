## MODIFIED Requirements

### Requirement: Policy principal selection
A policy SHALL be attached to a single principal, chosen in this order: `no_principal = true` (no principal, a reusable template); otherwise the first entry of `user_ids`; otherwise the group under the first entry of `group_keys`; otherwise the application under the first entry of `application_keys`. Other entries and lists of lower priority SHALL NOT be used. Every entry of `user_ids` MUST be a lowercase UUID. The entry that selects the principal MUST be a key of `groups` (for `group_keys`) or of `applications` (for `application_keys`); entries that are not used are not checked.

#### Scenario: Policy for a group
- **WHEN** a policy has `group_keys = ["developers"]` and no `user_ids`
- **THEN** the policy is attached to the `developers` group

#### Scenario: User wins over group
- **WHEN** a policy has `user_ids = ["<uuid>"]` and `group_keys = ["admins"]`
- **THEN** the policy is attached to the user only

#### Scenario: Policy template
- **WHEN** a policy has `no_principal = true` and `group_keys = ["admins"]`
- **THEN** the policy is created with `no_principal` and no user, group or application

#### Scenario: Only the first entry is used
- **WHEN** a policy has `group_keys = ["a", "b"]`
- **THEN** the policy is attached to group `a` only

#### Scenario: Invalid user ID
- **WHEN** a policy has `user_ids = ["bob"]`
- **THEN** the plan fails with "All user_ids must be valid UUID format."

#### Scenario: Unknown group
- **WHEN** a policy has `group_keys = ["missing"]`, no `user_ids`, `no_principal = false` and `groups` has no `missing` key
- **THEN** the plan fails with "The group_keys entry that selects a policy principal must be a key of the groups input."

#### Scenario: Unknown application
- **WHEN** a policy has `application_keys = ["missing"]`, no `user_ids`, no `group_keys`, `no_principal = false` and `applications` has no `missing` key
- **THEN** the plan fails with "The application_keys entry that selects a policy principal must be a key of the applications input."

#### Scenario: Unused unknown entry
- **WHEN** a policy has `group_keys = ["admins", "missing"]` and `groups` has `admins` only
- **THEN** the plan succeeds

## ADDED Requirements

### Requirement: Ignored principals warning
A `check` block named `policy_single_principal` SHALL warn, naming the policy keys, when a policy lists principals that are not used: more than one entry across `user_ids`, `group_keys` and `application_keys`, or any entry when `no_principal = true`. The check SHALL NOT fail the plan. The `policies` description and the README SHALL state the single-principal rule.

#### Scenario: Several principals
- **WHEN** a policy has `user_ids = ["<uuid>"]` and `group_keys = ["admins"]`
- **THEN** the check warns naming the policy and the policy is still planned for the user

#### Scenario: Several entries in one list
- **WHEN** a policy has `group_keys = ["a", "b"]`
- **THEN** the check warns naming the policy

#### Scenario: Template with principals
- **WHEN** a policy has `no_principal = true` and `group_keys = ["admins"]`
- **THEN** the check warns naming the policy

#### Scenario: One principal
- **WHEN** every policy lists at most one entry and none combines it with `no_principal = true`
- **THEN** the check does not warn
