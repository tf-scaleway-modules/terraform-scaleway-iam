# groups Specification

## Purpose
IAM groups and their application and user memberships, including groups whose membership is managed outside the module.

## Requirements

### Requirement: IAM groups
`groups` SHALL be a map of objects with `name` (required), `description` (default `""`), `tags` (default `[]`), `application_keys`, `user_keys` and `user_ids` (default `[]`). The module SHALL create one `scaleway_iam_group` per key in the organization given by `organization_id`. `name` MUST start with a letter, contain only letters, digits, hyphens and underscores, and be at most 63 characters.

#### Scenario: Group created
- **WHEN** `groups = { admins = { name = "admins" } }`
- **THEN** one group named `admins` is planned and `group_ids["admins"]` is its ID

#### Scenario: Invalid group name
- **WHEN** a group has `name = "-admins"`
- **THEN** the plan fails with "Group names must start with a letter and contain only alphanumeric characters, hyphens, and underscores (max 63 chars)."

### Requirement: Application memberships
The module SHALL create one `scaleway_iam_group_membership` per entry of a group's `application_keys`, linking the group to the application under that key of `applications`. Each entry MUST be a key of `applications`. The membership key SHALL be `<group key>-app-<application key>`.

#### Scenario: Application added to a group
- **WHEN** `groups = { devs = { name = "devs", application_keys = ["cicd"] } }` and an application `cicd` exists
- **THEN** one membership `devs-app-cicd` links the `devs` group and the `cicd` application

#### Scenario: Unknown application
- **WHEN** a group lists `application_keys = ["missing"]` and `applications` has no `missing` key
- **THEN** the plan fails with "Group application_keys must be keys of the applications input."

### Requirement: User memberships
The module SHALL create one membership per entry of `user_ids` (an existing user; key `<group key>-user-<first 8 characters of the ID>`) and one per entry of `user_keys` (a user created by the module under that key of `users`; key `<group key>-user-key-<user key>`). `user_ids` entries MUST be lowercase UUIDs sharing no first 8 characters within a group; `user_keys` entries MUST be keys of `users`.

#### Scenario: User added to a group
- **WHEN** `groups = { devs = { name = "devs", user_ids = ["12345678-1234-1234-1234-123456789012"] } }`
- **THEN** one membership `devs-user-12345678` links the `devs` group and that user

#### Scenario: Module user added in one apply
- **WHEN** `users = { bob = {...} }` and a group lists `user_keys = ["bob"]`
- **THEN** one membership `devs-user-key-bob` links the group and the user created under `bob`

#### Scenario: Invalid user ID
- **WHEN** a group has `user_ids = ["bob"]`
- **THEN** the plan fails with "All user_ids must be valid UUID format."

#### Scenario: User IDs sharing a prefix
- **WHEN** a group lists two user IDs that start with the same 8 characters
- **THEN** the plan fails with "user_ids of one group must be unique and must not share their first 8 characters (membership keys are derived from them)."

#### Scenario: Unknown user key
- **WHEN** a group lists `user_keys = ["missing"]` and `users` has no `missing` key
- **THEN** the plan fails with "Group user_keys must be keys of the users input."

### Requirement: Group outputs
The `groups` output SHALL expose per group `id`, `name`, `description`, `created_at` and `updated_at`; `group_ids` SHALL map each group key to its ID.

#### Scenario: No groups
- **WHEN** `groups = {}`
- **THEN** `groups`, `group_ids` and both `group_memberships` maps are empty

### Requirement: Group declares external membership
Every group SHALL set the provider argument `external_membership = true` and SHALL NOT set the group's `application_ids` or `user_ids`, because memberships are managed by the separate membership resources. The group resource SHALL NOT use `ignore_changes`.

#### Scenario: Member added outside the module
- **WHEN** a member is added to a group in the console
- **THEN** the next plan shows no change on the group and no membership is removed by the group resource

#### Scenario: Group without members
- **WHEN** a group lists no `application_keys`, `user_keys` or `user_ids`
- **THEN** the group is planned and no membership is created
