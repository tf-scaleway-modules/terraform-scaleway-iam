## MODIFIED Requirements

### Requirement: API key owner and format validation
Each API key MUST set exactly one of `application_key` and `user_id`. `application_key`, when set, MUST be a key of `applications`. `user_id` and `default_project_id`, when set, MUST be lowercase UUIDs. `expires_at`, when set, MUST match `YYYY-MM-DDTHH:MM:SSZ`.

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
