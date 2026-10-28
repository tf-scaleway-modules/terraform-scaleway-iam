# applications-and-api-keys Specification

## Purpose
IAM applications and the API keys bound to an application or a user, with optional mandatory expiration and a sensitive secret output.

## Requirements

### Requirement: IAM applications
`applications` SHALL be a map of objects with `name` (required), `description` (default `""`) and `tags` (default `[]`). The module SHALL create one `scaleway_iam_application` per key in the organization given by `organization_id`. `name` MUST start with a letter, contain only letters, digits, hyphens and underscores, and be at most 63 characters.

#### Scenario: Application created
- **WHEN** `applications = { terraform = { name = "terraform-automation", description = "Terraform" } }`
- **THEN** one application named `terraform-automation` is planned in the organization

#### Scenario: Invalid application name
- **WHEN** an application has `name = "1-app"` or `name = "my app"`
- **THEN** the plan fails with "Application names must start with a letter and contain only alphanumeric characters, hyphens, and underscores (max 63 chars)."

### Requirement: API keys
`api_keys` SHALL be a map of objects with the optional attributes `application_key`, `user_id`, `description` (default `""`), `expires_at`, `default_project_id` and `secret_id`. The module SHALL create one `scaleway_iam_api_key` per key, owned by the application created under `application_key` of `applications` when that is set, or by the user `user_id` when that is set. `description`, `expires_at`, `default_project_id` and `secret_id` (`null` when unset) SHALL be passed to the resource.

#### Scenario: Key for an application
- **WHEN** `applications = { terraform = {...} }` and `api_keys = { k = { application_key = "terraform" } }`
- **THEN** the API key `k` is planned for the `terraform` application

#### Scenario: Key for an existing user
- **WHEN** `api_keys = { u = { user_id = "<uuid>" } }`
- **THEN** the API key `u` is planned for that user and no application is referenced

#### Scenario: Key stored in a secret
- **WHEN** `api_keys = { k = { application_key = "terraform", secret_id = "<uuid>" } }`
- **THEN** the API key `k` is planned with that `secret_id` and the module plans no secret resource

#### Scenario: Key without secret
- **WHEN** a key does not set `secret_id`
- **THEN** the API key is planned with `secret_id` null and its plan is unchanged from the previous release

### Requirement: API key owner and format validation
Each API key MUST set exactly one of `application_key` and `user_id`. `application_key`, when set, MUST be a key of `applications`. `user_id` and `default_project_id`, when set, MUST be lowercase UUIDs. `secret_id`, when set, MUST be a lowercase UUID or a regional ID (`<region>/<uuid>`). `expires_at`, when set, MUST match `YYYY-MM-DDTHH:MM:SSZ`.

#### Scenario: Both owners
- **WHEN** a key sets `application_key = "terraform"` and `user_id = "<uuid>"`
- **THEN** the plan fails with "Each API key must specify either 'application_key' or 'user_id', but not both."

#### Scenario: No owner
- **WHEN** a key sets neither `application_key` nor `user_id`
- **THEN** the plan fails with the same validation error

#### Scenario: Unknown application
- **WHEN** a key sets `application_key = "missing"` and `applications` has no `missing` key
- **THEN** the plan fails with "application_key must be a key of the applications input."

#### Scenario: Invalid user ID
- **WHEN** `user_id = "not-a-uuid"`
- **THEN** the plan fails with "user_id must be a valid UUID format."

#### Scenario: Invalid default project ID
- **WHEN** `default_project_id = "not-a-uuid"`
- **THEN** the plan fails with "default_project_id must be a valid UUID format."

#### Scenario: Invalid secret ID
- **WHEN** `secret_id = "my-secret"`
- **THEN** the plan fails with "secret_id must be a UUID or a regional ID (<region>/<uuid>)."

#### Scenario: Regional secret ID accepted
- **WHEN** `secret_id = "fr-par/<uuid>"`
- **THEN** the plan succeeds

#### Scenario: Invalid expiration format
- **WHEN** `expires_at = "2026-12-31"`
- **THEN** the plan fails with "expires_at must be in ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ)."

### Requirement: Mandatory API key expiration
When `require_api_key_expiration` is `true`, every API key SHALL set `expires_at`; a key without it MUST fail the plan through a `precondition` on the API key resource naming the key, and the variable description SHALL say so. When `false` (default), keys without `expires_at` SHALL be accepted.

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
The `api_keys` output SHALL be sensitive and expose, per key, `id`, `access_key`, `secret_key`, `description`, `created_at` and `expires_at`. `secret_key` SHALL be `null` for a key that sets `secret_id`, because the secret is stored in Secret Manager and not in state; the output description SHALL say so and how to read it. `api_key_access_keys` SHALL map each key to its access key and `api_key_ids` to its ID; neither exposes the secret key.

#### Scenario: Reading credentials
- **WHEN** an API key `k` without `secret_id` is created
- **THEN** `api_key_access_keys["k"]` is its access key, and `api_keys["k"].secret_key` is its secret key through the sensitive output

#### Scenario: Secret stored in Secret Manager
- **WHEN** an API key `k` sets `secret_id`
- **THEN** `api_keys["k"].secret_key` is `null` and the value is read from the secret's latest version

#### Scenario: No API keys
- **WHEN** `api_keys = {}`
- **THEN** `api_keys`, `api_key_access_keys` and `api_key_ids` are empty maps

### Requirement: Mandatory API key secret storage
`require_api_key_secret_id` (`bool`, default `false`) SHALL, when `true`, make every API key set `secret_id`; a key without it MUST fail the plan through a `precondition` on the API key resource naming the key, and the variable description SHALL say so. When `false`, keys without `secret_id` SHALL be accepted.

#### Scenario: Secret storage required and missing
- **WHEN** `require_api_key_secret_id = true` and key `ci` has no `secret_id`
- **THEN** the plan fails with "API key 'ci' must set secret_id when require_api_key_secret_id is enabled."

#### Scenario: Secret storage required and present
- **WHEN** `require_api_key_secret_id = true` and every key has a valid `secret_id`
- **THEN** the plan succeeds

#### Scenario: Secret storage not required
- **WHEN** `require_api_key_secret_id = false` and a key has no `secret_id`
- **THEN** the plan succeeds and the key appears in `security_audit.api_keys_secret_in_state`
