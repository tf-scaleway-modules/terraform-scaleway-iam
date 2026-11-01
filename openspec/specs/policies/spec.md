# policies Specification

## Purpose
IAM policies with permission rules and the selection of their single principal.

## Requirements

### Requirement: IAM policies
`policies` SHALL be a map of objects with `name` and `rules` (required) and optional `description`, `tags`, `user_id`, `group_key`, `application_key` and `no_principal`. The module SHALL create one `scaleway_iam_policy` per key in the organization, with one `rule` block per entry of `rules` (`permission_set_names` required; `organization_wide`, `project_ids` and `condition` optional). `name` MUST start with a letter, contain only letters, digits, hyphens and underscores (max 63).

#### Scenario: Policy with two rules
- **WHEN** a policy declares one rule with `organization_wide = true` and one rule with `project_ids`
- **THEN** the policy is planned with two rule blocks, the first scoped to `organization_id` and the second to those projects

#### Scenario: Invalid policy name
- **WHEN** a policy has `name = "9-policy"`
- **THEN** the plan fails with "Policy names must start with a letter and contain only alphanumeric characters, hyphens, and underscores (max 63 chars)."

### Requirement: Policy rules are mandatory
Each policy MUST have at least one rule, and each rule MUST have at least one entry in `permission_set_names`.

#### Scenario: Policy without rules
- **WHEN** a policy has `rules = []`
- **THEN** the plan fails with "Each policy must have at least one rule."

#### Scenario: Rule without permission sets
- **WHEN** a rule has `permission_set_names = []`
- **THEN** the plan fails with "Each rule must have at least one permission_set_name."

### Requirement: Policy outputs
The `policies` output SHALL expose per policy `id`, `name`, `description`, `created_at`, `updated_at` and `editable`; `policy_ids` SHALL map each policy key to its ID.

#### Scenario: Policy ID lookup
- **WHEN** `policies = { dev = {...} }`
- **THEN** `policy_ids["dev"]` is the policy's ID

### Requirement: Rule permission-set scope documented
The `policies` description and the README SHALL state that all `permission_set_names` of one rule must have the same scope (organization or project), so a rule that mixes them is rejected by the provider at plan time, and that the module does not duplicate this check because it needs the live permission-set catalogue. The module SHALL pass `permission_set_names` unchanged to the provider.

#### Scenario: Mixed-scope rule
- **WHEN** one rule lists a project-scoped and an organization-scoped permission set
- **THEN** the provider rejects the plan, and the `policies` description tells the user to split the rule in two

#### Scenario: Names passed through
- **WHEN** a rule lists `["IAMReadOnly"]`
- **THEN** the policy rule carries exactly `["IAMReadOnly"]`

### Requirement: Single policy principal
A policy MUST set exactly one of `user_id`, `group_key`, `application_key` and `no_principal = true` (a reusable template). `user_id` MUST be a lowercase UUID, `group_key` a key of `groups` and `application_key` a key of `applications`.

#### Scenario: Policy for a group
- **WHEN** a policy has `group_key = "developers"`
- **THEN** the policy is attached to the `developers` group

#### Scenario: Policy template
- **WHEN** a policy has `no_principal = true` and no other principal
- **THEN** the policy is created with `no_principal` and no user, group or application

#### Scenario: Several principals
- **WHEN** a policy has `group_key = "a"` and `user_id = "<uuid>"`
- **THEN** the plan fails with "Each policy must set exactly one of user_id, group_key, application_key or no_principal = true."

#### Scenario: No principal
- **WHEN** a policy sets none of the four
- **THEN** the plan fails with the same validation error

#### Scenario: Invalid user ID
- **WHEN** a policy has `user_id = "bob"`
- **THEN** the plan fails with "user_id must be a valid UUID format."

#### Scenario: Unknown group
- **WHEN** a policy has `group_key = "missing"` and `groups` has no `missing` key
- **THEN** the plan fails with "group_key must be a key of the groups input."

#### Scenario: Unknown application
- **WHEN** a policy has `application_key = "missing"` and `applications` has no `missing` key
- **THEN** the plan fails with "application_key must be a key of the applications input."

### Requirement: Policy rule scope and condition
A rule SHALL be scoped to the whole organization with `organization_wide = true` (the module passes `organization_id`) or to `project_ids`, never both. A rule MAY set `condition`, a CEL expression passed unchanged to the rule. The `policies` description SHALL give an example condition.

#### Scenario: Both scopes
- **WHEN** a rule sets `organization_wide = true` and `project_ids = ["<uuid>"]`
- **THEN** the plan fails with "A rule must not set both organization_wide and project_ids."

#### Scenario: Condition passed through
- **WHEN** a rule sets `condition = "request.ip in ['203.0.113.0/24']"`
- **THEN** the policy rule carries exactly that condition

#### Scenario: No condition
- **WHEN** a rule sets no `condition`
- **THEN** the policy rule is planned with a null condition
