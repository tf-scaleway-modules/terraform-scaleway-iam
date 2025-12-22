# Scaleway IAM Terraform Module

[![Apache 2.0][apache-shield]][apache]
[![Terraform][terraform-badge]][terraform-url]
[![Scaleway Provider][scaleway-badge]][scaleway-url]
[![Latest Release][release-badge]][release-url]

A **production-ready** Terraform/OpenTofu module for creating and managing Scaleway IAM (Identity and Access Management) resources.

## Overview

This module provides comprehensive IAM management for Scaleway, enabling you to:

- Create and manage **Applications** (service accounts) for automation
- Generate **API Keys** with configurable expiration
- Organize identities using **Groups** with flexible membership
- Define access controls through **Policies** with fine-grained rules
- Invite and manage **Users** with customizable onboarding
- Manage **SSH Keys** for Instance access

### Key Features

- **Complete IAM Coverage**: Manage all Scaleway IAM resources from a single module
- **Flexible Architecture**: Use only the features you need
- **Security Best Practices**: Built-in validation, sensitive output handling, and expiration support
- **Production Ready**: Comprehensive outputs for integration with other modules
- **Well Documented**: Extensive inline documentation and examples

## Quick Start

### Prerequisites

- Terraform >= 1.10.7 or OpenTofu >= 1.10.7
- Scaleway account with appropriate permissions
- Organization ID from Scaleway Console

### Minimal Example

```hcl
module "iam" {
  source = "path/to/scaleway-iam"

  organization_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  project_name    = "my-project"

  # Create a Terraform automation application with API key
  applications = {
    terraform = {
      name        = "terraform"
      description = "Terraform automation"
    }
  }

  api_keys = {
    terraform_key = {
      application_key = "terraform"
      description     = "Terraform API key"
    }
  }
}

# Access the generated credentials
output "access_key" {
  value = module.iam.api_key_access_keys["terraform_key"]
}

output "secret_key" {
  value     = module.iam.api_keys["terraform_key"].secret_key
  sensitive = true
}
```

## Usage Examples

### Complete IAM Setup

```hcl
module "iam" {
  source = "path/to/scaleway-iam"

  organization_id = var.organization_id
  project_name    = var.project_name

  tags = ["environment:production", "managed-by:terraform"]

  # Applications
  applications = {
    terraform = {
      name        = "terraform-automation"
      description = "Infrastructure automation"
      tags        = ["automation"]
    }
    cicd = {
      name        = "gitlab-ci"
      description = "CI/CD pipeline"
      tags        = ["ci-cd"]
    }
  }

  # API Keys
  api_keys = {
    terraform_key = {
      application_key    = "terraform"
      description        = "Terraform key"
      default_project_id = var.project_id
    }
    cicd_key = {
      application_key = "cicd"
      description     = "CI/CD key"
      expires_at      = "2026-12-31T23:59:59Z"
    }
  }

  # Groups
  groups = {
    admins = {
      name             = "admins"
      description      = "Administrators"
      application_keys = ["terraform"]
    }
    developers = {
      name             = "developers"
      description      = "Development team"
      application_keys = ["cicd"]
    }
  }

  # Policies
  policies = {
    admin_policy = {
      name       = "admin-full-access"
      group_keys = ["admins"]
      rules = [{
        permission_set_names = ["AllProductsFullAccess"]
        organization_id      = var.organization_id
      }]
    }
    dev_policy = {
      name       = "developer-access"
      group_keys = ["developers"]
      rules = [{
        permission_set_names = ["InstancesFullAccess", "ObjectStorageFullAccess"]
        project_ids          = [var.project_id]
      }]
    }
  }

  # SSH Keys
  ssh_keys = {
    admin_key = {
      name       = "admin-laptop"
      public_key = file("~/.ssh/id_ed25519.pub")
    }
  }
}
```

### User Management

```hcl
module "iam" {
  source = "path/to/scaleway-iam"

  organization_id = var.organization_id

  users = {
    admin = {
      email               = "admin@example.com"
      username            = "admin"
      tags                = ["admin"]
      send_welcome_email  = true
      send_password_email = true
    }
    developer = {
      email               = "dev@example.com"
      username            = "developer"
      tags                = ["developer"]
      send_welcome_email  = true
      send_password_email = true
    }
  }

  groups = {
    admins = {
      name     = "admins"
      user_ids = [] # Add user IDs after they accept invitations
    }
  }
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Scaleway Organization                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │ Application │    │ Application │    │    User     │    │    User     │  │
│  │ (terraform) │    │   (cicd)    │    │  (admin)    │    │ (developer) │  │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘  │
│         │                  │                  │                  │          │
│         │                  │                  │                  │          │
│         ▼                  ▼                  ▼                  ▼          │
│  ┌─────────────┐    ┌─────────────┐                                         │
│  │   API Key   │    │   API Key   │                                         │
│  │(terraform_k)│    │  (cicd_key) │                                         │
│  └─────────────┘    └─────────────┘                                         │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                              Groups                                    │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐       │  │
│  │  │  admins         │  │  developers     │  │  readonly       │       │  │
│  │  │  - terraform    │  │  - cicd         │  │  - monitoring   │       │  │
│  │  │  - admin (user) │  │  - dev (user)   │  │                 │       │  │
│  │  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘       │  │
│  └───────────┼────────────────────┼────────────────────┼─────────────────┘  │
│              │                    │                    │                    │
│              ▼                    ▼                    ▼                    │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                             Policies                                   │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐       │  │
│  │  │ admin-policy    │  │ dev-policy      │  │ readonly-policy │       │  │
│  │  │ AllProducts     │  │ Instances,      │  │ AllProducts     │       │  │
│  │  │ FullAccess      │  │ Storage         │  │ ReadOnly        │       │  │
│  │  │ (organization)  │  │ (project)       │  │ (organization)  │       │  │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘       │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                        Project: my-project                             │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │  SSH Keys: admin-key, ci-deploy-key                                   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Common Permission Sets

| Permission Set | Description |
|---------------|-------------|
| `AllProductsFullAccess` | Full access to all Scaleway products |
| `AllProductsReadOnly` | Read-only access to all products |
| `InstancesFullAccess` | Full access to Instances |
| `InstancesReadOnly` | Read-only access to Instances |
| `ObjectStorageFullAccess` | Full access to Object Storage |
| `ObjectStorageReadOnly` | Read-only access to Object Storage |
| `ContainersFullAccess` | Full access to Containers |
| `DatabasesFullAccess` | Full access to Databases |
| `IAMFullAccess` | Full access to IAM |
| `IAMReadOnly` | Read-only access to IAM |
| `BillingFullAccess` | Full access to Billing |
| `BillingReadOnly` | Read-only access to Billing |

See [Scaleway IAM Documentation](https://www.scaleway.com/en/docs/identity-and-access-management/iam/reference-content/permission-sets/) for the complete list.

## Security Best Practices

### API Key Management

1. **Use Applications**: Create applications for automation instead of user API keys
2. **Set Expiration**: Always set `expires_at` for time-limited access
3. **Minimal Permissions**: Grant only required permission sets
4. **Rotate Regularly**: Implement key rotation policies
5. **Secure Storage**: Store secrets in a secrets manager

### Policy Design

1. **Group-Based**: Attach policies to groups, not individual identities
2. **Least Privilege**: Start with minimal permissions and add as needed
3. **Project Scope**: Prefer project-scoped rules over organization-wide
4. **Regular Audits**: Review policies and memberships periodically

### SSH Key Security

1. **Ed25519 Preferred**: Use Ed25519 keys for better security
2. **Disable Unused**: Set `disabled = true` for emergency/backup keys
3. **Remove Promptly**: Delete keys when no longer needed

## Examples

- [Minimal](./examples/minimal/) - Basic application with API key
- [Complete](./examples/complete/) - Full-featured IAM setup

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.7 |
| <a name="requirement_scaleway"></a> [scaleway](#requirement\_scaleway) | ~> 2.64 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_scaleway"></a> [scaleway](#provider\_scaleway) | 2.65.1 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [scaleway_iam_api_key.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/iam_api_key) | resource |
| [scaleway_iam_application.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/iam_application) | resource |
| [scaleway_iam_group.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/iam_group) | resource |
| [scaleway_iam_group_membership.applications](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/iam_group_membership) | resource |
| [scaleway_iam_group_membership.users](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/iam_group_membership) | resource |
| [scaleway_iam_policy.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/iam_policy) | resource |
| [scaleway_iam_ssh_key.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/iam_ssh_key) | resource |
| [scaleway_iam_user.this](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/resources/iam_user) | resource |
| [terraform_data.application_deletion_protection](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.group_deletion_protection](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.policy_deletion_protection](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [scaleway_account_project.project](https://registry.terraform.io/providers/scaleway/scaleway/latest/docs/data-sources/account_project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_key_max_expiration_days"></a> [api\_key\_max\_expiration\_days](#input\_api\_key\_max\_expiration\_days) | Maximum number of days an API key can be valid.<br/><br/>Set to 0 to disable this check.<br/><br/>Recommended values:<br/>- 90 days for production<br/>- 365 days for long-running automation | `number` | `0` | no |
| <a name="input_api_keys"></a> [api\_keys](#input\_api\_keys) | Map of IAM API keys to create.<br/><br/>API keys authenticate programmatic access to Scaleway APIs.<br/><br/>IMPORTANT: Each key must be associated with EITHER an application\_key<br/>OR a user\_id, but NOT both.<br/><br/>- application\_key: Reference to an application defined in var.applications<br/>- user\_id: UUID of an existing IAM user<br/><br/>The default\_project\_id can be used to set a default project context<br/>for API calls made with this key.<br/><br/>Example:<pre>hcl<br/>api_keys = {<br/>  terraform_key = {<br/>    application_key    = "terraform"  # References var.applications["terraform"]<br/>    description        = "Terraform automation key"<br/>    expires_at         = "2025-12-31T23:59:59Z"<br/>    default_project_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"<br/>  }<br/>  user_automation = {<br/>    user_id     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"<br/>    description = "Personal automation key for admin user"<br/>  }<br/>}</pre>SECURITY NOTES:<br/>- Set expires\_at for time-limited access<br/>- Use application keys over user keys when possible<br/>- Rotate keys regularly<br/>- Never expose keys in logs or version control | <pre>map(object({<br/>    application_key    = optional(string)<br/>    user_id            = optional(string)<br/>    description        = optional(string, "")<br/>    expires_at         = optional(string)<br/>    default_project_id = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_applications"></a> [applications](#input\_applications) | Map of IAM applications (service accounts) to create.<br/><br/>Applications provide identity for non-human users, enabling:<br/>- Programmatic access via API keys<br/>- Fine-grained permissions via policies<br/>- Audit trail separation from human users<br/><br/>Each application key becomes part of the resource identifier.<br/><br/>Example:<pre>hcl<br/>applications = {<br/>  terraform = {<br/>    name        = "terraform-automation"<br/>    description = "Terraform infrastructure management"<br/>    tags        = ["automation", "terraform"]<br/>  }<br/>  cicd = {<br/>    name        = "gitlab-ci"<br/>    description = "GitLab CI/CD pipeline"<br/>    tags        = ["ci", "gitlab"]<br/>  }<br/>}</pre> | <pre>map(object({<br/>    name        = string<br/>    description = optional(string, "")<br/>    tags        = optional(list(string), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Enable deletion protection for critical IAM resources.<br/><br/>When enabled, prevents accidental deletion of:<br/>- IAM Applications<br/>- IAM Groups<br/>- IAM Policies<br/><br/>Set to false only in development or when intentionally destroying resources.<br/><br/>IMPORTANT: You must set this to false before running terraform destroy. | `bool` | `true` | no |
| <a name="input_groups"></a> [groups](#input\_groups) | Map of IAM groups to create.<br/><br/>Groups enable collective permission management by:<br/>- Grouping related users and applications<br/>- Attaching policies to multiple identities at once<br/>- Simplifying permission audits<br/><br/>Best practice: Organize groups by role or function rather than by team.<br/><br/>Example:<pre>hcl<br/>groups = {<br/>  admins = {<br/>    name        = "organization-admins"<br/>    description = "Full administrative access"<br/>    tags        = ["admin", "privileged"]<br/>    external_membership = false<br/>  }<br/>  developers = {<br/>    name        = "developers"<br/>    description = "Development team access"<br/>    application_keys = ["cicd"]<br/>    user_ids = [<br/>      "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"<br/>    ]<br/>  }<br/>  readonly = {<br/>    name        = "read-only-users"<br/>    description = "Read-only access for monitoring"<br/>    external_membership = true  # Membership managed outside this module<br/>  }<br/>}</pre> | <pre>map(object({<br/>    name                = string<br/>    description         = optional(string, "")<br/>    tags                = optional(list(string), [])<br/>    application_keys    = optional(list(string), [])<br/>    user_ids            = optional(list(string), [])<br/>    external_membership = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_organization_id"></a> [organization\_id](#input\_organization\_id) | Scaleway Organization ID.<br/><br/>The organization is the top-level entity in Scaleway's hierarchy.<br/>Find this in the Scaleway Console under Organization Settings.<br/><br/>Format: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) | `string` | n/a | yes |
| <a name="input_policies"></a> [policies](#input\_policies) | Map of IAM policies to create.<br/><br/>Policies grant permissions to users, groups, or applications through rules.<br/>Each rule specifies:<br/>- permission\_set\_names: List of predefined permission sets to grant<br/>- organization\_id: For organization-wide permissions (optional)<br/>- project\_ids: For project-specific permissions (optional)<br/><br/>A policy can have multiple rules for different scopes.<br/><br/>Common permission sets:<br/>- AllProductsFullAccess: Full access to all products<br/>- AllProductsReadOnly: Read-only access to all products<br/>- InstancesFullAccess: Full access to Instances<br/>- ObjectStorageFullAccess: Full access to Object Storage<br/>- IAMReadOnly: Read-only access to IAM<br/>- BillingReadOnly: Read-only access to billing<br/><br/>Example:<pre>hcl<br/>policies = {<br/>  admin_policy = {<br/>    name        = "admin-full-access"<br/>    description = "Full administrative access"<br/>    no_principal = false<br/>    user_ids = ["xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"]<br/>    group_keys = ["admins"]<br/>    application_keys = ["terraform"]<br/>    rules = [<br/>      {<br/>        permission_set_names = ["AllProductsFullAccess"]<br/>        organization_id      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"<br/>      }<br/>    ]<br/>  }<br/>  dev_policy = {<br/>    name        = "developer-access"<br/>    description = "Developer project access"<br/>    group_keys  = ["developers"]<br/>    rules = [<br/>      {<br/>        permission_set_names = ["InstancesFullAccess", "ObjectStorageFullAccess"]<br/>        project_ids = [<br/>          "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"<br/>        ]<br/>      }<br/>    ]<br/>  }<br/>}</pre> | <pre>map(object({<br/>    name             = string<br/>    description      = optional(string, "")<br/>    tags             = optional(list(string), [])<br/>    no_principal     = optional(bool, false)<br/>    user_ids         = optional(list(string), [])<br/>    group_keys       = optional(list(string), [])<br/>    application_keys = optional(list(string), [])<br/>    rules = list(object({<br/>      permission_set_names = list(string)<br/>      organization_id      = optional(string)<br/>      project_ids          = optional(list(string), [])<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Scaleway Project name where project-scoped resources will be created.<br/><br/>Projects provide logical isolation within an organization.<br/>SSH keys and some resources are created at project level.<br/><br/>Set to null if you only want to manage organization-level IAM resources.<br/><br/>Naming rules:<br/>- Must start with a lowercase letter<br/>- Can contain lowercase letters, numbers, and hyphens<br/>- Must be 2-63 characters long | `string` | `null` | no |
| <a name="input_require_api_key_expiration"></a> [require\_api\_key\_expiration](#input\_require\_api\_key\_expiration) | Require all API keys to have an expiration date.<br/><br/>When enabled, the module will fail validation if any API key<br/>is configured without an expires\_at value.<br/><br/>This is a security best practice to ensure credentials are rotated. | `bool` | `false` | no |
| <a name="input_ssh_keys"></a> [ssh\_keys](#input\_ssh\_keys) | Map of SSH keys to create.<br/><br/>SSH keys provide secure access to Scaleway Instances and other resources<br/>that support SSH authentication.<br/><br/>Keys are associated with the project specified in var.project\_name.<br/>If project\_id is specified in the key configuration, it overrides<br/>the default project.<br/><br/>You can provide the public key directly or use file() function<br/>to read from a file.<br/><br/>Example:<pre>hcl<br/>ssh_keys = {<br/>  admin_key = {<br/>    name       = "admin-laptop"<br/>    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... admin@example.com"<br/>  }<br/>  ci_key = {<br/>    name       = "gitlab-ci"<br/>    public_key = file("~/.ssh/gitlab-ci.pub")<br/>    disabled   = false<br/>  }<br/>}</pre>SECURITY NOTES:<br/>- Use Ed25519 or RSA 4096-bit keys<br/>- Protect private keys with passphrases<br/>- Rotate keys regularly<br/>- Remove unused keys promptly | <pre>map(object({<br/>    name       = string<br/>    public_key = string<br/>    project_id = optional(string)<br/>    disabled   = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Global tags applied to all resources that support tagging.<br/><br/>Tags are key-value pairs for organizing and categorizing resources.<br/>Common uses:<br/>- Environment identification (environment:production)<br/>- Cost allocation (team:platform, project:website)<br/>- Automation (managed-by:terraform)<br/><br/>Format: List of strings (e.g., ["env:prod", "team:devops"]) | `list(string)` | `[]` | no |
| <a name="input_users"></a> [users](#input\_users) | Map of IAM users to invite to the organization.<br/><br/>IMPORTANT: Creating a user sends an invitation email to the specified address.<br/>The user must accept the invitation to complete account setup.<br/><br/>Users can be added to groups and policies after creation.<br/>For automated/programmatic access, prefer applications over users.<br/><br/>Example:<pre>hcl<br/>users = {<br/>  admin_user = {<br/>    email    = "admin@example.com"<br/>    username = "admin"<br/>    tags     = ["admin", "human"]<br/>  }<br/>  developer = {<br/>    email    = "dev@example.com"<br/>    username = "developer"<br/>    tags     = ["developer"]<br/>    send_password_email = true<br/>    send_welcome_email  = true<br/>  }<br/>}</pre> | <pre>map(object({<br/>    email               = string<br/>    username            = string<br/>    tags                = optional(list(string), [])<br/>    send_password_email = optional(bool, false)<br/>    send_welcome_email  = optional(bool, true)<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_key_access_keys"></a> [api\_key\_access\_keys](#output\_api\_key\_access\_keys) | Map of API key names to their access keys (public part only, non-sensitive). |
| <a name="output_api_key_ids"></a> [api\_key\_ids](#output\_api\_key\_ids) | Map of API key names to their IDs. |
| <a name="output_api_keys"></a> [api\_keys](#output\_api\_keys) | Map of all created IAM API keys (SENSITIVE).<br/><br/>Each entry contains:<br/>- id: The API key's unique identifier<br/>- access\_key: The access key (public part)<br/>- secret\_key: The secret key (SENSITIVE - handle with extreme care)<br/>- description: The API key's description<br/>- created\_at: Creation timestamp<br/>- expires\_at: Expiration timestamp (if set)<br/><br/>SECURITY WARNING:<br/>- Store secrets in a secrets manager (Vault, AWS Secrets Manager, etc.)<br/>- Never log or expose these values<br/>- Rotate keys regularly<br/>- This output is marked sensitive but values persist in state |
| <a name="output_application_ids"></a> [application\_ids](#output\_application\_ids) | Map of application keys to their IDs for easy lookup. |
| <a name="output_applications"></a> [applications](#output\_applications) | Map of all created IAM applications.<br/><br/>Each entry contains:<br/>- id: The application's unique identifier<br/>- name: The application's display name<br/>- description: The application's description<br/>- created\_at: Creation timestamp<br/>- updated\_at: Last update timestamp<br/>- editable: Whether the application can be modified |
| <a name="output_group_ids"></a> [group\_ids](#output\_group\_ids) | Map of group keys to their IDs for easy lookup. |
| <a name="output_group_memberships"></a> [group\_memberships](#output\_group\_memberships) | Summary of all group memberships created by this module.<br/><br/>Includes both application and user memberships organized by group. |
| <a name="output_groups"></a> [groups](#output\_groups) | Map of all created IAM groups.<br/><br/>Each entry contains:<br/>- id: The group's unique identifier<br/>- name: The group's display name<br/>- description: The group's description<br/>- created\_at: Creation timestamp<br/>- updated\_at: Last update timestamp |
| <a name="output_policies"></a> [policies](#output\_policies) | Map of all created IAM policies.<br/><br/>Each entry contains:<br/>- id: The policy's unique identifier<br/>- name: The policy's display name<br/>- description: The policy's description<br/>- created\_at: Creation timestamp<br/>- updated\_at: Last update timestamp<br/>- editable: Whether the policy can be modified |
| <a name="output_policy_ids"></a> [policy\_ids](#output\_policy\_ids) | Map of policy keys to their IDs for easy lookup. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The ID of the Scaleway project (if project\_name was provided). |
| <a name="output_security_audit"></a> [security\_audit](#output\_security\_audit) | Security-relevant information for auditing.<br/><br/>Includes:<br/>- API keys without expiration (security risk)<br/>- Users without 2FA enabled<br/>- Disabled SSH keys count |
| <a name="output_ssh_key_fingerprints"></a> [ssh\_key\_fingerprints](#output\_ssh\_key\_fingerprints) | Map of SSH key names to their fingerprints. |
| <a name="output_ssh_key_ids"></a> [ssh\_key\_ids](#output\_ssh\_key\_ids) | Map of SSH key names to their IDs for easy lookup. |
| <a name="output_ssh_key_public_keys"></a> [ssh\_key\_public\_keys](#output\_ssh\_key\_public\_keys) | Map of SSH key names to their public keys. |
| <a name="output_ssh_keys"></a> [ssh\_keys](#output\_ssh\_keys) | Map of all created IAM SSH keys.<br/><br/>Each entry contains:<br/>- id: The SSH key's unique identifier<br/>- name: The SSH key's display name<br/>- fingerprint: The SSH key fingerprint<br/>- created\_at: Creation timestamp<br/>- updated\_at: Last update timestamp<br/>- project\_id: Associated project ID<br/>- disabled: Whether the key is disabled<br/><br/>Note: Public keys are not included in this output.<br/>Use ssh\_key\_public\_keys if you need them. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary statistics for all IAM resources created by this module.<br/><br/>Useful for monitoring and auditing purposes. |
| <a name="output_user_details"></a> [user\_details](#output\_user\_details) | Full user details including PII (SENSITIVE).<br/><br/>Contains email addresses - handle according to privacy regulations. |
| <a name="output_user_ids"></a> [user\_ids](#output\_user\_ids) | Map of user keys to their IDs for easy lookup. |
| <a name="output_users"></a> [users](#output\_users) | Map of all created IAM users (SENSITIVE - contains PII).<br/><br/>Each entry contains:<br/>- id: The user's unique identifier<br/>- created\_at: Creation timestamp<br/>- updated\_at: Last update timestamp<br/>- status: The user's account status<br/>- type: The user's type (owner, guest, etc.)<br/>- two\_factor\_enabled: Whether 2FA is enabled<br/><br/>Note: Email addresses are excluded from non-sensitive outputs.<br/>Use user\_details output if you need email addresses. |
<!-- END_TF_DOCS -->

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Run `terraform fmt` and `terraform validate`
5. Submit a merge request

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
[release-badge]: https://img.shields.io/gitlab/v/release/leminnov/terraform/modules/scaleway-iam?include_prereleases&sort=semver
[release-url]: https://gitlab.com/leminnov/terraform/modules/scaleway-iam/-/releases
