## MODIFIED Requirements

### Requirement: Application memberships
For each group with `external_membership = false`, the module SHALL create one `scaleway_iam_group_membership` per entry of `application_keys`, linking the group to the application created under that key of `applications`. Each entry MUST be a key of `applications`. The membership key SHALL be `<group key>-app-<application key>`.

#### Scenario: Application added to a group
- **WHEN** `groups = { devs = { name = "devs", application_keys = ["cicd"] } }` and an application `cicd` exists
- **THEN** one membership `devs-app-cicd` links the `devs` group and the `cicd` application

#### Scenario: Unknown application
- **WHEN** a group with `external_membership = false` lists `application_keys = ["missing"]` and `applications` has no `missing` key
- **THEN** the plan fails with "Group application_keys must be keys of the applications input."

### Requirement: User memberships
For each group with `external_membership = false`, the module SHALL create one `scaleway_iam_group_membership` per entry of `user_ids`, linking the group to that user. The membership key SHALL be `<group key>-user-<first 8 characters of the user ID>`, so the first 8 characters of the entries of one group MUST be unique. Every entry of `user_ids` MUST be a lowercase UUID.

#### Scenario: User added to a group
- **WHEN** `groups = { devs = { name = "devs", user_ids = ["12345678-1234-1234-1234-123456789012"] } }`
- **THEN** one membership `devs-user-12345678` links the `devs` group and that user

#### Scenario: Invalid user ID
- **WHEN** a group has `user_ids = ["bob"]`
- **THEN** the plan fails with "All user_ids must be valid UUID format."

#### Scenario: User IDs sharing a prefix
- **WHEN** a group with `external_membership = false` lists two user IDs that start with the same 8 characters
- **THEN** the plan fails with "user_ids of one group must be unique and must not share their first 8 characters (membership keys are derived from them)."

### Requirement: External membership
When `external_membership = true`, the module SHALL create no membership resource for that group, whatever `application_keys` and `user_ids` contain, and SHALL NOT validate those two lists against `applications` or for prefix collisions.

#### Scenario: Membership managed elsewhere
- **WHEN** a group has `external_membership = true` and `application_keys = ["cicd"]`
- **THEN** the group is created and no membership is planned for it

#### Scenario: Unchecked lists
- **WHEN** a group has `external_membership = true`, `application_keys = ["missing"]` and two user IDs sharing a prefix
- **THEN** the plan succeeds
