## MODIFIED Requirements

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

### Requirement: Optional inputs and defaults
All inputs except `organization_id` SHALL be optional. `tags` SHALL default to `[]`, `enable_deletion_protection` to `true`, `require_api_key_expiration` and `require_api_key_secret_id` to `false`, and `applications`, `api_keys`, `groups`, `policies`, `users` and `ssh_keys` to `{}`. Each map input SHALL create one resource per key, so a key is the stable address of the resource.

#### Scenario: Only the organization ID
- **WHEN** only `organization_id` is set
- **THEN** the plan creates no IAM resource and the module is valid

#### Scenario: Map keys address resources
- **WHEN** `applications = { terraform = { name = "terraform" } }`
- **THEN** the application is addressed as `scaleway_iam_application.this["terraform"]`

### Requirement: Sensitive outputs
Exactly two outputs SHALL be marked `sensitive = true`: `api_keys`, which carries the `secret_key` of each API key, and `user_details`, which carries user email addresses (personal data). Every other output SHALL be non-sensitive, including `api_key_access_keys`, `api_key_ids`, `users`, `ssh_key_public_keys`, `summary` and `security_audit`, and no description of a non-sensitive output SHALL claim that it is sensitive. The secret keys remain readable in the state, except those of API keys that set `secret_id`, which are never stored in state.

#### Scenario: Secret key in the sensitive output only
- **WHEN** an API key is created
- **THEN** its `secret_key` is exposed only through the sensitive `api_keys` output, and `api_key_access_keys` and `api_key_ids` expose the access key and the ID only

#### Scenario: Reading a sensitive output
- **WHEN** a caller reads `module.iam.api_keys["terraform_key"].secret_key` and wraps it in a sensitive output
- **THEN** the value is available to the caller and hidden in CLI output

#### Scenario: Users output description
- **WHEN** the `users` output description is read
- **THEN** it does not claim to be sensitive and points to `user_details` for email addresses

#### Scenario: Secret key kept out of state
- **WHEN** an API key sets `secret_id`
- **THEN** its secret key is in neither the state nor any output, and the `api_keys` output description names the secret as the place to read it

### Requirement: Security audit output
The `security_audit` output SHALL expose lists of input map keys: `api_keys_without_expiration`, `api_keys_expiring_soon`, `api_keys_secret_in_state`, `disabled_ssh_keys` and `active_ssh_keys`. `api_keys_expiring_soon` lists every key with an `expires_at`, whatever the date; the name is kept for compatibility and the description says so. `api_keys_secret_in_state` lists every key without `secret_id`, whose secret key is stored in state.

#### Scenario: Audit lists
- **WHEN** API key `a` has no `expires_at` and API key `b` has one
- **THEN** `security_audit.api_keys_without_expiration = ["a"]` and `security_audit.api_keys_expiring_soon = ["b"]`

#### Scenario: Active and disabled SSH keys
- **WHEN** SSH key `x` has `disabled = true` and `y` has `disabled = false`
- **THEN** `security_audit.disabled_ssh_keys = ["x"]` and `security_audit.active_ssh_keys = ["y"]`

#### Scenario: Secret keys in state
- **WHEN** API key `a` has no `secret_id` and API key `b` has one
- **THEN** `security_audit.api_keys_secret_in_state = ["a"]`
