## MODIFIED Requirements

### Requirement: Global tags
Global `tags` SHALL be merged with the per-resource `tags` (global first, duplicates removed) on applications, groups, policies and users. Tags SHALL NOT be applied to API keys, SSH keys or memberships. The module SHALL NOT validate tag content: the Scaleway API enforces its own tag rules, and the `tags` description SHALL NOT state rules the module does not enforce.

#### Scenario: Global and local tags
- **WHEN** `tags = ["env=prod"]` and an application has `tags = ["ci", "env=prod"]`
- **THEN** the application carries the tags `env=prod` and `ci`, each once

#### Scenario: No tags
- **WHEN** neither global nor per-resource tags are set
- **THEN** the resource carries an empty tag list

### Requirement: Sensitive outputs
Exactly two outputs SHALL be marked `sensitive = true`: `api_keys`, which carries the `secret_key` of each API key, and `user_details`, which carries user email addresses (personal data). Every other output SHALL be non-sensitive, including `api_key_access_keys`, `api_key_ids`, `users`, `ssh_key_public_keys`, `summary` and `security_audit`, and no description of a non-sensitive output SHALL claim that it is sensitive. The secret keys remain readable in the state.

#### Scenario: Secret key in the sensitive output only
- **WHEN** an API key is created
- **THEN** its `secret_key` is exposed only through the sensitive `api_keys` output, and `api_key_access_keys` and `api_key_ids` expose the access key and the ID only

#### Scenario: Reading a sensitive output
- **WHEN** a caller reads `module.iam.api_keys["terraform_key"].secret_key` and wraps it in a sensitive output
- **THEN** the value is available to the caller and hidden in CLI output

#### Scenario: Users output description
- **WHEN** the `users` output description is read
- **THEN** it does not claim to be sensitive and points to `user_details` for email addresses

### Requirement: Summary and audit outputs
The `summary` output SHALL expose `organization_id`, `project_id` and one count per resource family (`applications_count`, `api_keys_count`, `groups_count`, `policies_count`, `users_count`, `ssh_keys_count`, `group_memberships_count`). The `security_audit` output SHALL expose lists of input map keys: `api_keys_without_expiration` (`expires_at` null), `api_keys_expiring_soon` (any `expires_at` set, whatever the date: the name is kept for compatibility and the description SHALL say so), `disabled_ssh_keys` and `active_ssh_keys`.

#### Scenario: Counts
- **WHEN** one application, two API keys and one group with two application memberships are declared
- **THEN** `summary.applications_count = 1`, `summary.api_keys_count = 2`, `summary.groups_count = 1` and `summary.group_memberships_count = 2`

#### Scenario: Audit lists
- **WHEN** API key `a` has no `expires_at` and API key `b` has one
- **THEN** `security_audit.api_keys_without_expiration = ["a"]` and `security_audit.api_keys_expiring_soon = ["b"]`

#### Scenario: Active and disabled SSH keys
- **WHEN** SSH key `x` has `disabled = true` and `y` has `disabled = false`
- **THEN** `security_audit.disabled_ssh_keys = ["x"]` and `security_audit.active_ssh_keys = ["y"]`
