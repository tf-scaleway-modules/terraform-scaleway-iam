# Scaleway IAM Terraform Module

[![Apache 2.0][apache-shield]][apache]
[![Terraform][terraform-badge]][terraform-url]
[![Scaleway Provider][scaleway-badge]][scaleway-url]
[![Latest Release][release-badge]][release-url]

A **production-ready** Terraform/OpenTofu module for creating and managing Scaleway IAM services.

## Overview


### Key Features

## Quick Start

### Prerequisites


### Examples

### Minimal Example


## Usage Examples



## Architecture



<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.7 |
| <a name="requirement_scaleway"></a> [scaleway](#requirement\_scaleway) | ~> 2.64 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_scaleway"></a> [scaleway](#provider\_scaleway) | ~> 2.64 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [scaleway_account_project.project](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/data-sources/account_project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | Scaleway Organization ID.<br/><br/>The organization is the top-level entity in Scaleway's hierarchy.<br/>Find this in the Scaleway Console under Organization Settings.<br/><br/>Format: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Scaleway Project name where all resources will be created.<br/><br/>Projects provide logical isolation within an organization.<br/>All buckets, objects, and policies will be created in this project.<br/><br/>Naming rules:<br/>- Must start with a lowercase letter<br/>- Can contain lowercase letters, numbers, and hyphens<br/>- Must be 2-63 characters long | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Scaleway region for object storage.<br/><br/>Available regions:<br/>- fr-par: Paris, France (Europe)<br/>- nl-ams: Amsterdam, Netherlands (Europe)<br/>- pl-waw: Warsaw, Poland (Europe)<br/><br/>Choose the region closest to your users for optimal latency.<br/>Data residency requirements may also influence this choice. | `string` | `"fr-par"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Global tags applied to all resources.<br/><br/>Tags are key-value pairs for organizing and categorizing resources.<br/>Common uses:<br/>- Environment identification (environment:production)<br/>- Cost allocation (team:platform, project:website)<br/>- Automation (managed-by:terraform)<br/><br/>Format: Map of strings (e.g., {env = "prod", team = "devops"}) | `map(string)` | `{}` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->


## Security Best Practices


## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a merge request

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

Copyright 2025 - This module is independently maintained and not affiliated with Scaleway.

## Disclaimer

This module is provided "as is" without warranty of any kind. Always test in non-production environments first.

---

[apache]: https://opensource.org/licenses/Apache-2.0
[apache-shield]: https://img.shields.io/badge/License-Apache%202.0-blue.svg
[terraform-badge]: https://img.shields.io/badge/Terraform-%3E%3D1.10-623CE4
[terraform-url]: https://www.terraform.io
[scaleway-badge]: https://img.shields.io/badge/Scaleway%20Provider-%3E%3D2.64-4f0599
[scaleway-url]: https://registry.terraform.io/providers/scaleway/scaleway/
[release-badge]: https://img.shields.io/gitlab/v/release/leminnov/terraform/modules/scaleway-storage?include_prereleases&sort=semver
[release-url]: https://gitlab.com/leminnov/terraform/modules/scaleway-storage/-/releases
