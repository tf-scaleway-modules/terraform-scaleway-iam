# groups Specification

## Purpose
IAM groups and their application and user memberships, including groups whose membership is managed outside the module.

## Requirements

### Requirement: IAM groups
`groups` SHALL be a map of objects with `name` (required), `description` (default `""`), `tags` (default `[]`), `application_keys` (default `[]`), `user_ids` (default `[]`) and `external_membership` (default `false`). The module SHALL create one `scaleway_iam_group` per key in the organization given by `organization_id`. `name` MUST start with a letter, contain only letters, digits, hyphens and underscores, and be at most 63 characters.

#### Scenario: Group created
- **WHEN** `groups = { admins = { name = "admins" } }`
- **THEN** one group named `admins` is planned and `group_ids["admins"]` is its ID

#### Scenario: Invalid group name
- **WHEN** a group has `name = "-admins"`
- **THEN** the plan fails with "Group names must start with a letter and contain only alphanumeric characters, hyphens, and underscores (max 63 chars)."

### Requirement: Group resource ignores membership attributes
The group resource SHALL ignore changes to its `application_ids` and `user_ids` attributes, because memberships are managed by separate membership resources.

#### Scenario: Membership drift ignored on the group
- **WHEN** members are added to the group outside this module
- **THEN** the next plan shows no change on the `scaleway_iam_group` resource for `application_ids` or `user_ids`

### Requirement: Application memberships
For each group with `external_membership = false`, the module SHALL create one `scaleway_iam_group_membership` per entry of `application_keys`, linking the group to the application created under that key of `applications`. The membership key SHALL be `<group key>-app-<application key>`.

#### Scenario: Application added to a group
- **WHEN** `groups = { devs = { name = "devs", application_keys = ["cicd"] } }` and an application `cicd` exists
- **THEN** one membership `devs-app-cicd` links the `devs` group and the `cicd` application

### Requirement: User memberships
For each group with `external_membership = false`, the module SHALL create one `scaleway_iam_group_membership` per entry of `user_ids`, linking the group to that user. The membership key SHALL be `<group key>-user-<first 8 characters of the user ID>`. Every entry of `user_ids` MUST be a lowercase UUID.

#### Scenario: User added to a group
- **WHEN** `groups = { devs = { name = "devs", user_ids = ["12345678-1234-1234-1234-123456789012"] } }`
- **THEN** one membership `devs-user-12345678` links the `devs` group and that user

#### Scenario: Invalid user ID
- **WHEN** a group has `user_ids = ["bob"]`
- **THEN** the plan fails with "All user_ids must be valid UUID format."

### Requirement: External membership
When `external_membership = true`, the module SHALL create no membership resource for that group, whatever `application_keys` and `user_ids` contain.

#### Scenario: Membership managed elsewhere
- **WHEN** a group has `external_membership = true` and `application_keys = ["cicd"]`
- **THEN** the group is created and no membership is planned for it

### Requirement: Group outputs
The `groups` output SHALL expose per group `id`, `name`, `description`, `created_at` and `updated_at`; `group_ids` SHALL map each group key to its ID.

#### Scenario: No groups
- **WHEN** `groups = {}`
- **THEN** `groups`, `group_ids` and both `group_memberships` maps are empty
