## ADDED Requirements

### Requirement: IAM applications
`applications` SHALL be a map of objects with `name` (required), `description` (default `""`) and `tags` (default `[]`). The module SHALL create one `scaleway_iam_application` per key in the organization given by `organization_id`. `name` MUST start with a letter, contain only letters, digits, hyphens and underscores, and be at most 63 characters.

#### Scenario: Application created
- **WHEN** `applications = { terraform = { name = "terraform-automation", description = "Terraform" } }`
- **THEN** one application named `terraform-automation` is planned in the organization

#### Scenario: Invalid application name
- **WHEN** an application has `name = "1-app"` or `name = "my app"`
- **THEN** the plan fails with "Application names must start with a letter and contain only alphanumeric characters, hyphens, and underscores (max 63 chars)."

### Requirement: API keys
`api_keys` SHALL be a map of objects with the optional attributes `application_key`, `user_id`, `description` (default `""`), `expires_at` and `default_project_id`. The module SHALL create one `scaleway_iam_api_key` per key. When `application_key` is set, the key SHALL belong to the application created under that key of `applications`; when `user_id` is set, it SHALL belong to that user. `description`, `expires_at` and `default_project_id` SHALL be passed to the resource.

#### Scenario: Key for an application
- **WHEN** `applications = { terraform = {...} }` and `api_keys = { k = { application_key = "terraform" } }`
- **THEN** the API key `k` is planned for the `terraform` application

#### Scenario: Key for an existing user
- **WHEN** `api_keys = { u = { user_id = "<uuid>" } }`
- **THEN** the API key `u` is planned for that user and no application is referenced

### Requirement: API key owner and format validation
Each API key MUST set exactly one of `application_key` and `user_id`. `user_id` and `default_project_id`, when set, MUST be lowercase UUIDs. `expires_at`, when set, MUST match `YYYY-MM-DDTHH:MM:SSZ`.

#### Scenario: Both owners
- **WHEN** a key sets `application_key = "terraform"` and `user_id = "<uuid>"`
- **THEN** the plan fails with "Each API key must specify either 'application_key' or 'user_id', but not both."

#### Scenario: No owner
- **WHEN** a key sets neither `application_key` nor `user_id`
- **THEN** the plan fails with the same validation error

#### Scenario: Invalid user ID
- **WHEN** `user_id = "not-a-uuid"`
- **THEN** the plan fails with "user_id must be a valid UUID format."

#### Scenario: Invalid default project ID
- **WHEN** `default_project_id = "not-a-uuid"`
- **THEN** the plan fails with "default_project_id must be a valid UUID format."

#### Scenario: Invalid expiration format
- **WHEN** `expires_at = "2026-12-31"`
- **THEN** the plan fails with "expires_at must be in ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ)."

### Requirement: Mandatory API key expiration
When `require_api_key_expiration` is `true`, every API key SHALL set `expires_at`; a key without it MUST fail the plan through a `precondition` on the API key resource naming the key. When `false` (default), keys without `expires_at` SHALL be accepted.

#### Scenario: Expiration required and missing
- **WHEN** `require_api_key_expiration = true` and key `ci` has no `expires_at`
- **THEN** the plan fails with "API key 'ci' must have an expiration date (expires_at) when require_api_key_expiration is enabled."

#### Scenario: Expiration required and present
- **WHEN** `require_api_key_expiration = true` and every key has a valid `expires_at`
- **THEN** the plan succeeds

#### Scenario: Expiration not required
- **WHEN** `require_api_key_expiration = false` and a key has no `expires_at`
- **THEN** the plan succeeds and the key appears in `security_audit.api_keys_without_expiration`

### Requirement: API key outputs
The `api_keys` output SHALL be sensitive and expose, per key, `id`, `access_key`, `secret_key`, `description`, `created_at` and `expires_at`. `api_key_access_keys` SHALL map each key to its access key and `api_key_ids` to its ID; neither exposes the secret key.

#### Scenario: Reading credentials
- **WHEN** an API key `k` is created
- **THEN** `api_key_access_keys["k"]` is its access key, and `api_keys["k"].secret_key` is its secret key through the sensitive output

#### Scenario: No API keys
- **WHEN** `api_keys = {}`
- **THEN** `api_keys`, `api_key_access_keys` and `api_key_ids` are empty maps
