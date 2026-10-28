## ADDED Requirements

### Requirement: Rule permission-set scope documented
The `policies` description and the README SHALL state that all `permission_set_names` of one rule must have the same scope (organization or project), so a rule that mixes them is rejected by the provider at plan time, and that the module does not duplicate this check because it needs the live permission-set catalogue. The module SHALL pass `permission_set_names` unchanged to the provider.

#### Scenario: Mixed-scope rule
- **WHEN** one rule lists a project-scoped and an organization-scoped permission set
- **THEN** the provider rejects the plan, and the `policies` description tells the user to split the rule in two

#### Scenario: Names passed through
- **WHEN** a rule lists `["IAMReadOnly"]`
- **THEN** the policy rule carries exactly `["IAMReadOnly"]`
