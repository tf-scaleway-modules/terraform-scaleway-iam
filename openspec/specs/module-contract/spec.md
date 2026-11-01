# module-contract Specification

## Purpose
Supported tool and provider versions, input defaults and shared validation, global tags and the 20 outputs with their sensitivity.

## Requirements

### Requirement: Supported tooling and providers
The module SHALL require OpenTofu or Terraform `>= 1.10.7` and the `scaleway/scaleway` provider `~> 2.89`. It SHALL NOT declare any `provider {}` or `backend {}` block: the caller configures the Scaleway provider and the backend.

#### Scenario: Older tool version
- **WHEN** the module is initialized with a tool older than 1.10.7
- **THEN** initialization fails on the `required_version` constraint

#### Scenario: Older provider version
- **WHEN** the module is initialized with a lock file that pins provider 2.88.0 or older
- **THEN** initialization fails on the provider constraint until `tofu init -upgrade` is run

#### Scenario: Caller owns the provider
- **WHEN** the module is called from a root module that configures the `scaleway` provider
- **THEN** the module uses that provider configuration and declares none of its own

### Requirement: Organization input
`organization_id` SHALL be a required string and MUST match a lowercase UUID (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`). It SHALL be passed as `organization_id` to every application, group, policy and user. IAM resources are organization-scoped, so the input stays.

#### Scenario: Invalid organization ID
- **WHEN** `organization_id = "my-org"`
- **THEN** the plan fails with "Organization ID must be a valid UUID format."

#### Scenario: Uppercase organization ID
- **WHEN** `organization_id` contains uppercase hexadecimal letters
- **THEN** the plan fails with the same validation error

#### Scenario: Missing organization ID
- **WHEN** `organization_id` is not set
- **THEN** the plan fails because the variable has no default

### Requirement: Optional inputs and defaults
All inputs except `organization_id` SHALL be optional. `project_id` SHALL default to `null`, `tags` to `[]`, `enable_deletion_protection` and `require_api_key_secret_id` to `true`, `require_api_key_expiration` to `false`, and `applications`, `api_keys`, `groups`, `policies`, `users` and `ssh_keys` to `{}`. Each map input SHALL create one resource per key, so a key is the stable address of the resource.

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
The module SHALL expose, per resource family, a detail map and, for applications, groups, policies and users, an ID map, both keyed by the input map key: `applications`/`application_ids`, `groups`/`group_ids`, `policies`/`policy_ids`, `users`/`user_ids`, and `ssh_keys`. `users` MUST NOT expose the email and `ssh_keys` MUST NOT expose the public key.

#### Scenario: Application ID lookup
- **WHEN** `applications = { terraform = { name = "terraform" } }`
- **THEN** `application_ids["terraform"]` is the application's ID and `applications["terraform"]` contains `id`, `name`, `description`, `created_at`, `updated_at` and `editable`

#### Scenario: User output without email
- **WHEN** a user is created
- **THEN** `users[<key>]` contains no `email` attribute

#### Scenario: SSH key output without public key
- **WHEN** an SSH key is created
- **THEN** `ssh_keys[<key>]` holds `id`, `name`, `fingerprint` and `project_id` and no `public_key` attribute

### Requirement: Sensitive outputs
Exactly two outputs SHALL be `sensitive = true`: `api_key_secret_keys` (secret keys) and `user_details` (emails). Every other output, including `api_keys`, `users`, `ssh_keys` and `security_audit`, SHALL be non-sensitive, and no description SHALL claim otherwise. A secret key stays readable in the state unless its API key sets `secret_id`.

#### Scenario: Secret key in the sensitive output only
- **WHEN** an API key without `secret_id` is created
- **THEN** its secret key is exposed only through `api_key_secret_keys`, and `api_keys[<key>]` has no `secret_key` attribute

#### Scenario: Reading a sensitive output
- **WHEN** a caller reads `module.iam.api_key_secret_keys["terraform_key"]` and wraps it in a sensitive output
- **THEN** the value is available to the caller and hidden in CLI output

#### Scenario: Secret key kept out of state
- **WHEN** an API key sets `secret_id`
- **THEN** its secret key is in neither the state nor any output, and the `api_key_secret_keys` description names the secret as the place to read it

#### Scenario: Users output description
- **WHEN** the `users` output description is read
- **THEN** it does not claim to be sensitive and points to `user_details` for email addresses

### Requirement: Security audit output
The `security_audit` output SHALL expose lists of input map keys: `api_keys_without_expiration`, `api_keys_with_expiration`, `api_keys_secret_in_state`, `users_without_mfa`, `disabled_ssh_keys` and `active_ssh_keys`. `users_without_mfa` lists users whose `mfa` attribute is false.

#### Scenario: Audit lists
- **WHEN** API key `a` has no `expires_at` and API key `b` has one
- **THEN** `security_audit.api_keys_without_expiration = ["a"]` and `security_audit.api_keys_with_expiration = ["b"]`

#### Scenario: Active and disabled SSH keys
- **WHEN** SSH key `x` has `disabled = true` and `y` has `disabled = false`
- **THEN** `security_audit.disabled_ssh_keys = ["x"]` and `security_audit.active_ssh_keys = ["y"]`

#### Scenario: Secret keys in state
- **WHEN** API key `a` has no `secret_id` and API key `b` has one
- **THEN** `security_audit.api_keys_secret_in_state = ["a"]`

#### Scenario: Users without MFA
- **WHEN** user `u` has `mfa = false` and user `v` has `mfa = true`
- **THEN** `security_audit.users_without_mfa = ["u"]`

### Requirement: Group membership output
The `group_memberships` output SHALL expose two maps, `applications` (entries with `group_id` and `application_id`) and `users` (entries with `group_id` and `user_id`), keyed by the membership key.

#### Scenario: Application membership
- **WHEN** group `devs` lists application key `cicd`
- **THEN** `group_memberships.applications["devs-app-cicd"]` holds the group ID and the application ID

### Requirement: Optional project ID
`project_id` SHALL be an optional string defaulting to `null`. When set it MUST be a lowercase UUID. It SHALL be the default project of every SSH key and the default of `default_project_id` for every API key; when `null`, the provider default project applies. The module SHALL read no data source and SHALL NOT look a project up by name.

#### Scenario: Project ID set
- **WHEN** `project_id = "<uuid>"` and an SSH key sets no `project_id`
- **THEN** the SSH key is planned in that project

#### Scenario: Project ID omitted
- **WHEN** `project_id` is `null` and an SSH key sets no `project_id`
- **THEN** the SSH key argument is `null`, the provider default project applies and no data source is read

#### Scenario: Invalid project ID
- **WHEN** `project_id = "my-project"`
- **THEN** the plan fails with "project_id must be a valid UUID format."
