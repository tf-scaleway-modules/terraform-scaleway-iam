## MODIFIED Requirements

### Requirement: SSH keys
`ssh_keys` SHALL be a map of objects with `name` and `public_key` (required), `project_id` (optional) and `disabled` (default `false`). The module SHALL create one `scaleway_iam_ssh_key` per key, in `project_id` when set, otherwise in the project resolved from `project_name`. When `project_name` is `null`, every key MUST set `project_id`. `name` MUST start with a letter, contain only letters, digits, hyphens and underscores (max 63). `public_key` MUST start with `ssh-rsa`, `ssh-ed25519` or `ssh-ecdsa` and a base64 body. `project_id` MUST be a lowercase UUID.

#### Scenario: Key in the module project
- **WHEN** `project_name = "my-project"` and an SSH key has no `project_id`
- **THEN** the key is created in the `my-project` project

#### Scenario: Key in another project
- **WHEN** an SSH key has `project_id = "<uuid>"`
- **THEN** the key is created in that project

#### Scenario: Key without any project
- **WHEN** `project_name` is `null` and an SSH key has no `project_id`
- **THEN** the plan fails with "Each SSH key needs a project_id when project_name is not set."

#### Scenario: Key with its own project and no project name
- **WHEN** `project_name` is `null` and every SSH key has a `project_id`
- **THEN** the plan succeeds

#### Scenario: Invalid key name
- **WHEN** an SSH key has `name = "my key"`
- **THEN** the plan fails with "SSH key names must start with a letter and contain only alphanumeric characters, hyphens, and underscores (max 63 chars)."

#### Scenario: Invalid public key
- **WHEN** an SSH key has `public_key = "not-a-key"`
- **THEN** the plan fails with "Public keys must be valid SSH public key format (ssh-rsa, ssh-ed25519, or ssh-ecdsa)."

#### Scenario: Invalid project ID
- **WHEN** an SSH key has `project_id = "not-a-uuid"`
- **THEN** the plan fails with "project_id must be a valid UUID format."
