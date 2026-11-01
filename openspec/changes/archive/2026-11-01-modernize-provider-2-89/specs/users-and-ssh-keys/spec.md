## MODIFIED Requirements

### Requirement: User outputs
The `users` output SHALL expose per user `id`, `created_at`, `updated_at`, `status`, `type`, `mfa` and `locked`, without the email. `user_ids` SHALL map each user key to its ID. The `user_details` output SHALL be sensitive and expose `id`, `email`, `username`, `created_at`, `updated_at`, `deletable`, `last_login_at`, `status` and `type`.

#### Scenario: Email only in the sensitive output
- **WHEN** a user is created
- **THEN** the email is exposed through `user_details` only

#### Scenario: MFA state visible
- **WHEN** a user is created
- **THEN** `users[<key>].mfa` and `users[<key>].locked` hold the values the API reports

#### Scenario: No users
- **WHEN** `users = {}`
- **THEN** `users`, `user_ids` and `user_details` are empty maps

### Requirement: SSH keys
`ssh_keys` SHALL be a map of objects with `name` and `public_key` (required), `project_id` (optional) and `disabled` (default `false`). The module SHALL create one `scaleway_iam_ssh_key` per key, in `project_id` when set, otherwise in the module `project_id`, otherwise in the provider default project. `public_key` MUST start with `ssh-rsa`, `ssh-ed25519` or `ecdsa-sha2-nistp256`, `-nistp384` or `-nistp521`.

#### Scenario: Key in the module project
- **WHEN** `project_id = "<uuid>"` and an SSH key has no `project_id`
- **THEN** the key is created in that project

#### Scenario: Key in another project
- **WHEN** an SSH key has its own `project_id = "<uuid>"`
- **THEN** the key is created in that project

#### Scenario: Key without any project
- **WHEN** neither the module nor the key sets a `project_id`
- **THEN** the plan succeeds and the key is created in the provider default project

#### Scenario: Key with its own project and no project name
- **WHEN** the module `project_id` is `null` and every SSH key has a `project_id`
- **THEN** the plan succeeds and each key is created in its own project

#### Scenario: Invalid key name
- **WHEN** an SSH key has `name = "my key"`
- **THEN** the plan fails with "SSH key names must start with a letter and contain only alphanumeric characters, hyphens, and underscores (max 63 chars)."

#### Scenario: Invalid public key
- **WHEN** an SSH key has `public_key = "not-a-key"` or starts with `ssh-ecdsa`
- **THEN** the plan fails with "Public keys must be valid SSH public key format (ssh-rsa, ssh-ed25519 or ecdsa-sha2-nistp256/384/521)."

#### Scenario: ECDSA key accepted
- **WHEN** an SSH key has `public_key = "ecdsa-sha2-nistp256 AAAA..."`
- **THEN** the plan succeeds

#### Scenario: Invalid project ID
- **WHEN** an SSH key has `project_id = "not-a-uuid"`
- **THEN** the plan fails with "project_id must be a valid UUID format."
