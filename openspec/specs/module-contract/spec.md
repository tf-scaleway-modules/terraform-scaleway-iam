# module-contract Specification

## Purpose
Supported tool and provider versions, input defaults and shared validation, global tags and the 20 outputs with their sensitivity.

## Requirements

### Requirement: Supported tooling and providers
The module SHALL require OpenTofu or Terraform `>= 1.10.7` and the `scaleway/scaleway` provider `~> 2.86`. It SHALL NOT declare any `provider {}` or `backend {}` block: the caller configures the Scaleway provider and the backend.

#### Scenario: Older tool version
- **WHEN** the module is initialized with a tool older than 1.10.7
- **THEN** initialization fails on the `required_version` constraint

#### Scenario: Caller owns the provider
- **WHEN** the module is called from a root module that configures the `scaleway` provider
- **THEN** the module uses that provider configuration and declares none of its own

### Requirement: Organization input
`organization_id` SHALL be a required string and MUST match a lowercase UUID (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`). It SHALL be passed as `organization_id` to every application, group, policy and user, and to the project lookup.

#### Scenario: Invalid organization ID
- **WHEN** `organization_id = "my-org"`
- **THEN** the plan fails with "Organization ID must be a valid UUID format."

#### Scenario: Uppercase organization ID
- **WHEN** `organization_id` contains uppercase hexadecimal letters
- **THEN** the plan fails with the same validation error

#### Scenario: Missing organization ID
- **WHEN** `organization_id` is not set
- **THEN** the plan fails because the variable has no default

### Requirement: Optional project name
`project_name` SHALL be an optional string defaulting to `null`. When set it MUST start with a lowercase letter, contain only lowercase letters, digits and hyphens, end with a letter or digit and be 2 to 63 characters long. When set, the module SHALL look the project up by name in the organization and expose its ID as `project_id`. When `null`, no lookup SHALL be made and `project_id` SHALL be `null`.

#### Scenario: Project name set
- **WHEN** `project_name = "my-project"`
- **THEN** one `scaleway_account_project` data source is read and the `project_id` output is the ID of that project

#### Scenario: Project name omitted
- **WHEN** `project_name` is `null`
- **THEN** no data source is read and the `project_id` output is `null`

#### Scenario: Invalid project name
- **WHEN** `project_name = "My_Project"`
- **THEN** the plan fails with "Project name must be lowercase alphanumeric with hyphens, start with a letter, and be 2-63 characters."

#### Scenario: Single-character project name
- **WHEN** `project_name = "a"`
- **THEN** the plan fails with the same validation error

### Requirement: Optional inputs and defaults
All inputs except `organization_id` SHALL be optional. `tags` SHALL default to `[]`, `enable_deletion_protection` to `true`, `require_api_key_expiration` to `false`, and `applications`, `api_keys`, `groups`, `policies`, `users` and `ssh_keys` to `{}`. Each map input SHALL create one resource per key, so a key is the stable address of the resource.

#### Scenario: Only the organization ID
- **WHEN** only `organization_id` is set
- **THEN** the plan creates no IAM resource and the module is valid

#### Scenario: Map keys address resources
- **WHEN** `applications = { terraform = { name = "terraform" } }`
- **THEN** the application is addressed as `scaleway_iam_application.this["terraform"]`

### Requirement: Global tags
Global `tags` SHALL be merged with the per-resource `tags` (global first, duplicates removed) on applications, groups, policies and users. Tags SHALL NOT be applied to API keys, SSH keys or memberships. The module SHALL NOT validate tag content: the Scaleway API enforces its own tag rules, and the `tags` description SHALL NOT state rules the module does not enforce.

#### Scenario: Global and local tags
- **WHEN** `tags = ["env=prod"]` and an application has `tags = ["ci", "env=prod"]`
- **THEN** the application carries the tags `env=prod` and `ci`, each once

#### Scenario: No tags
- **WHEN** neither global nor per-resource tags are set
- **THEN** the resource carries an empty tag list

### Requirement: Identifier outputs
The module SHALL expose `project_id` and, per resource family, a detail map and an ID map keyed by the input map key: `applications`/`application_ids`, `groups`/`group_ids`, `policies`/`policy_ids`, `users`/`user_ids`, `ssh_keys`/`ssh_key_ids`. `users` MUST NOT expose the email and `ssh_keys` MUST NOT expose the public key; `ssh_key_fingerprints` and `ssh_key_public_keys` map SSH key keys to those values.

#### Scenario: Application ID lookup
- **WHEN** `applications = { terraform = { name = "terraform" } }`
- **THEN** `application_ids["terraform"]` is the application's ID and `applications["terraform"]` contains `id`, `name`, `description`, `created_at`, `updated_at` and `editable`

#### Scenario: User output without email
- **WHEN** a user is created
- **THEN** `users[<key>]` contains no `email` attribute

#### Scenario: SSH key output without public key
- **WHEN** an SSH key is created
- **THEN** `ssh_keys[<key>]` contains no `public_key` attribute and `ssh_key_public_keys[<key>]` holds it

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

### Requirement: Summary output
The `summary` output SHALL expose `organization_id`, `project_id` and one count per resource family (`applications_count`, `api_keys_count`, `groups_count`, `policies_count`, `users_count`, `ssh_keys_count`, `group_memberships_count`).

#### Scenario: Counts
- **WHEN** one application, two API keys and one group with two application memberships are declared
- **THEN** `summary.applications_count = 1`, `summary.api_keys_count = 2`, `summary.groups_count = 1` and `summary.group_memberships_count = 2`

### Requirement: Security audit output
The `security_audit` output SHALL expose lists of input map keys: `api_keys_without_expiration`, `api_keys_expiring_soon`, `disabled_ssh_keys` and `active_ssh_keys`. `api_keys_expiring_soon` lists every key with an `expires_at`, whatever the date; the name is kept for compatibility and the description says so.

#### Scenario: Audit lists
- **WHEN** API key `a` has no `expires_at` and API key `b` has one
- **THEN** `security_audit.api_keys_without_expiration = ["a"]` and `security_audit.api_keys_expiring_soon = ["b"]`

#### Scenario: Active and disabled SSH keys
- **WHEN** SSH key `x` has `disabled = true` and `y` has `disabled = false`
- **THEN** `security_audit.disabled_ssh_keys = ["x"]` and `security_audit.active_ssh_keys = ["y"]`

### Requirement: Group membership output
The `group_memberships` output SHALL expose two maps, `applications` (entries with `group_id` and `application_id`) and `users` (entries with `group_id` and `user_id`), keyed by the membership key.

#### Scenario: Application membership
- **WHEN** group `devs` lists application key `cicd`
- **THEN** `group_memberships.applications["devs-app-cicd"]` holds the group ID and the application ID
