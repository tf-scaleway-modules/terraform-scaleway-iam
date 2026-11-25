## MODIFIED Requirements

### Requirement: Supported tooling and providers
The module SHALL require OpenTofu or Terraform `>= 1.11.0`, declared once in `required_version` and read by both tools, and the `scaleway/scaleway` provider `~> 2.89`. It SHALL NOT declare any `provider {}` or `backend {}` block: the caller configures the Scaleway provider and the backend.

#### Scenario: Older tool version
- **WHEN** the module is initialized with OpenTofu or Terraform older than 1.11.0
- **THEN** initialization fails on the `required_version` constraint

#### Scenario: Older provider version
- **WHEN** the module is initialized with a lock file that pins provider 2.88.0 or older
- **THEN** initialization fails on the provider constraint until `tofu init -upgrade` is run

#### Scenario: Caller owns the provider
- **WHEN** the module is called from a root module that configures the `scaleway` provider
- **THEN** the module uses that provider configuration and declares none of its own

#### Scenario: Both tools validate
- **WHEN** `tofu validate` and `terraform validate` run on the module root and on each example
- **THEN** both succeed
