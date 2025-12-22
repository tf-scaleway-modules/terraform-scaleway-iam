# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              INPUT VARIABLES                                  ║
# ║                                                                                ║
# ║  All configurable parameters for the Scaleway IAM module.                     ║
# ║  Variables are organized by category with comprehensive validation.           ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Organization & Project
# ------------------------------------------------------------------------------
# Required identifiers for Scaleway resource organization.
# These determine where resources are created and billed.
# ==============================================================================

variable "organization_id" {
  description = <<-EOT
    Scaleway Organization ID.

    The organization is the top-level entity in Scaleway's hierarchy.
    Find this in the Scaleway Console under Organization Settings.

    Format: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
  EOT
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.organization_id))
    error_message = "Organization ID must be a valid UUID format."
  }
}

variable "project_name" {
  description = <<-EOT
    Scaleway Project name where project-scoped resources will be created.

    Projects provide logical isolation within an organization.
    SSH keys and some resources are created at project level.

    Set to null if you only want to manage organization-level IAM resources.

    Naming rules:
    - Must start with a lowercase letter
    - Can contain lowercase letters, numbers, and hyphens
    - Must be 2-63 characters long
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.project_name == null || can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.project_name))
    error_message = "Project name must be lowercase alphanumeric with hyphens, start with a letter, and be 2-63 characters."
  }
}

# ==============================================================================
# Global Configuration
# ------------------------------------------------------------------------------
# Settings that apply to all resources created by this module.
# ==============================================================================

variable "tags" {
  description = <<-EOT
    Global tags applied to all resources that support tagging.

    Tags are key-value pairs for organizing and categorizing resources.
    Common uses:
    - Environment identification (environment:production)
    - Cost allocation (team:platform, project:website)
    - Automation (managed-by:terraform)

    Format: List of strings (e.g., ["env:prod", "team:devops"])
  EOT
  type        = list(string)
  default     = []
}

# ==============================================================================
# Security Configuration
# ------------------------------------------------------------------------------
# Settings that control security behavior of the module.
# ==============================================================================

variable "enable_deletion_protection" {
  description = <<-EOT
    Enable deletion protection for critical IAM resources.

    When enabled, prevents accidental deletion of:
    - IAM Applications
    - IAM Groups
    - IAM Policies

    Set to false only in development or when intentionally destroying resources.

    IMPORTANT: You must set this to false before running terraform destroy.
  EOT
  type        = bool
  default     = true
}

variable "require_api_key_expiration" {
  description = <<-EOT
    Require all API keys to have an expiration date.

    When enabled, the module will fail validation if any API key
    is configured without an expires_at value.

    This is a security best practice to ensure credentials are rotated.
  EOT
  type        = bool
  default     = false
}

variable "api_key_max_expiration_days" {
  description = <<-EOT
    Maximum number of days an API key can be valid.

    Set to 0 to disable this check.

    Recommended values:
    - 90 days for production
    - 365 days for long-running automation
  EOT
  type        = number
  default     = 0

  validation {
    condition     = var.api_key_max_expiration_days >= 0
    error_message = "api_key_max_expiration_days must be >= 0."
  }
}

# ==============================================================================
# IAM Applications
# ------------------------------------------------------------------------------
# Applications represent non-human identities (service accounts) for:
# - CI/CD pipelines
# - Terraform automation
# - Backend services
# - Custom scripts
# ==============================================================================

variable "applications" {
  description = <<-EOT
    Map of IAM applications (service accounts) to create.

    Applications provide identity for non-human users, enabling:
    - Programmatic access via API keys
    - Fine-grained permissions via policies
    - Audit trail separation from human users

    Each application key becomes part of the resource identifier.

    Example:
    ```hcl
    applications = {
      terraform = {
        name        = "terraform-automation"
        description = "Terraform infrastructure management"
        tags        = ["automation", "terraform"]
      }
      cicd = {
        name        = "gitlab-ci"
        description = "GitLab CI/CD pipeline"
        tags        = ["ci", "gitlab"]
      }
    }
    ```
  EOT
  type = map(object({
    name        = string
    description = optional(string, "")
    tags        = optional(list(string), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.applications : can(regex("^[a-zA-Z][a-zA-Z0-9_-]{0,62}$", v.name))
    ])
    error_message = "Application names must start with a letter and contain only alphanumeric characters, hyphens, and underscores (max 63 chars)."
  }
}

# ==============================================================================
# IAM API Keys
# ------------------------------------------------------------------------------
# API keys provide authentication credentials for:
# - Applications (recommended)
# - Users (for personal automation)
#
# SECURITY: API keys should have minimal required permissions and
# be rotated regularly. Never commit keys to version control.
# ==============================================================================

variable "api_keys" {
  description = <<-EOT
    Map of IAM API keys to create.

    API keys authenticate programmatic access to Scaleway APIs.

    IMPORTANT: Each key must be associated with EITHER an application_key
    OR a user_id, but NOT both.

    - application_key: Reference to an application defined in var.applications
    - user_id: UUID of an existing IAM user

    The default_project_id can be used to set a default project context
    for API calls made with this key.

    Example:
    ```hcl
    api_keys = {
      terraform_key = {
        application_key    = "terraform"  # References var.applications["terraform"]
        description        = "Terraform automation key"
        expires_at         = "2025-12-31T23:59:59Z"
        default_project_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      }
      user_automation = {
        user_id     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        description = "Personal automation key for admin user"
      }
    }
    ```

    SECURITY NOTES:
    - Set expires_at for time-limited access
    - Use application keys over user keys when possible
    - Rotate keys regularly
    - Never expose keys in logs or version control
  EOT
  type = map(object({
    application_key    = optional(string)
    user_id            = optional(string)
    description        = optional(string, "")
    expires_at         = optional(string)
    default_project_id = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.api_keys :
      (v.application_key != null && v.user_id == null) ||
      (v.application_key == null && v.user_id != null)
    ])
    error_message = "Each API key must specify either 'application_key' or 'user_id', but not both."
  }

  validation {
    condition = alltrue([
      for k, v in var.api_keys :
      v.user_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", v.user_id))
    ])
    error_message = "user_id must be a valid UUID format."
  }

  validation {
    condition = alltrue([
      for k, v in var.api_keys :
      v.default_project_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", v.default_project_id))
    ])
    error_message = "default_project_id must be a valid UUID format."
  }

  validation {
    condition = alltrue([
      for k, v in var.api_keys :
      v.expires_at == null || can(regex("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", v.expires_at))
    ])
    error_message = "expires_at must be in ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ)."
  }
}

# ==============================================================================
# IAM Groups
# ------------------------------------------------------------------------------
# Groups organize users and applications for collective permission management.
# Attach policies to groups rather than individual identities when possible.
# ==============================================================================

variable "groups" {
  description = <<-EOT
    Map of IAM groups to create.

    Groups enable collective permission management by:
    - Grouping related users and applications
    - Attaching policies to multiple identities at once
    - Simplifying permission audits

    Best practice: Organize groups by role or function rather than by team.

    Example:
    ```hcl
    groups = {
      admins = {
        name        = "organization-admins"
        description = "Full administrative access"
        tags        = ["admin", "privileged"]
        external_membership = false
      }
      developers = {
        name        = "developers"
        description = "Development team access"
        application_keys = ["cicd"]
        user_ids = [
          "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        ]
      }
      readonly = {
        name        = "read-only-users"
        description = "Read-only access for monitoring"
        external_membership = true  # Membership managed outside this module
      }
    }
    ```
  EOT
  type = map(object({
    name                = string
    description         = optional(string, "")
    tags                = optional(list(string), [])
    application_keys    = optional(list(string), [])
    user_ids            = optional(list(string), [])
    external_membership = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.groups : can(regex("^[a-zA-Z][a-zA-Z0-9_-]{0,62}$", v.name))
    ])
    error_message = "Group names must start with a letter and contain only alphanumeric characters, hyphens, and underscores (max 63 chars)."
  }

  validation {
    condition = alltrue([
      for k, v in var.groups : alltrue([
        for user_id in v.user_ids :
        can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", user_id))
      ])
    ])
    error_message = "All user_ids must be valid UUID format."
  }
}

# ==============================================================================
# IAM Policies
# ------------------------------------------------------------------------------
# Policies define access permissions using rules that specify:
# - Which permission sets to grant
# - At what scope (organization or project level)
#
# Permission sets are predefined collections of permissions.
# See Scaleway documentation for available permission sets.
# ==============================================================================

variable "policies" {
  description = <<-EOT
    Map of IAM policies to create.

    Policies grant permissions to users, groups, or applications through rules.
    Each rule specifies:
    - permission_set_names: List of predefined permission sets to grant
    - organization_id: For organization-wide permissions (optional)
    - project_ids: For project-specific permissions (optional)

    A policy can have multiple rules for different scopes.

    Common permission sets:
    - AllProductsFullAccess: Full access to all products
    - AllProductsReadOnly: Read-only access to all products
    - InstancesFullAccess: Full access to Instances
    - ObjectStorageFullAccess: Full access to Object Storage
    - IAMReadOnly: Read-only access to IAM
    - BillingReadOnly: Read-only access to billing

    Example:
    ```hcl
    policies = {
      admin_policy = {
        name        = "admin-full-access"
        description = "Full administrative access"
        no_principal = false
        user_ids = ["xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"]
        group_keys = ["admins"]
        application_keys = ["terraform"]
        rules = [
          {
            permission_set_names = ["AllProductsFullAccess"]
            organization_id      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
          }
        ]
      }
      dev_policy = {
        name        = "developer-access"
        description = "Developer project access"
        group_keys  = ["developers"]
        rules = [
          {
            permission_set_names = ["InstancesFullAccess", "ObjectStorageFullAccess"]
            project_ids = [
              "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
            ]
          }
        ]
      }
    }
    ```
  EOT
  type = map(object({
    name             = string
    description      = optional(string, "")
    tags             = optional(list(string), [])
    no_principal     = optional(bool, false)
    user_ids         = optional(list(string), [])
    group_keys       = optional(list(string), [])
    application_keys = optional(list(string), [])
    rules = list(object({
      permission_set_names = list(string)
      organization_id      = optional(string)
      project_ids          = optional(list(string), [])
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.policies : can(regex("^[a-zA-Z][a-zA-Z0-9_-]{0,62}$", v.name))
    ])
    error_message = "Policy names must start with a letter and contain only alphanumeric characters, hyphens, and underscores (max 63 chars)."
  }

  validation {
    condition = alltrue([
      for k, v in var.policies : length(v.rules) > 0
    ])
    error_message = "Each policy must have at least one rule."
  }

  validation {
    condition = alltrue([
      for k, v in var.policies : alltrue([
        for rule in v.rules : length(rule.permission_set_names) > 0
      ])
    ])
    error_message = "Each rule must have at least one permission_set_name."
  }

  validation {
    condition = alltrue([
      for k, v in var.policies : alltrue([
        for user_id in v.user_ids :
        can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", user_id))
      ])
    ])
    error_message = "All user_ids must be valid UUID format."
  }
}

# ==============================================================================
# IAM Users
# ------------------------------------------------------------------------------
# Users represent human identities in the organization.
# Note: Creating a user sends an invitation email to the specified address.
# ==============================================================================

variable "users" {
  description = <<-EOT
    Map of IAM users to invite to the organization.

    IMPORTANT: Creating a user sends an invitation email to the specified address.
    The user must accept the invitation to complete account setup.

    Users can be added to groups and policies after creation.
    For automated/programmatic access, prefer applications over users.

    Example:
    ```hcl
    users = {
      admin_user = {
        email    = "admin@example.com"
        username = "admin"
        tags     = ["admin", "human"]
      }
      developer = {
        email    = "dev@example.com"
        username = "developer"
        tags     = ["developer"]
        send_password_email = true
        send_welcome_email  = true
      }
    }
    ```
  EOT
  type = map(object({
    email               = string
    username            = string
    tags                = optional(list(string), [])
    send_password_email = optional(bool, false)
    send_welcome_email  = optional(bool, true)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.users : can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", v.email))
    ])
    error_message = "All email addresses must be valid email format."
  }

  validation {
    condition = alltrue([
      for k, v in var.users : can(regex("^[a-zA-Z][a-zA-Z0-9_-]{0,62}$", v.username))
    ])
    error_message = "Usernames must start with a letter and contain only alphanumeric characters, hyphens, and underscores (max 63 chars)."
  }
}

# ==============================================================================
# IAM SSH Keys
# ------------------------------------------------------------------------------
# SSH keys for accessing Scaleway resources (Instances, etc.).
# Keys are scoped to a specific project.
# ==============================================================================

variable "ssh_keys" {
  description = <<-EOT
    Map of SSH keys to create.

    SSH keys provide secure access to Scaleway Instances and other resources
    that support SSH authentication.

    Keys are associated with the project specified in var.project_name.
    If project_id is specified in the key configuration, it overrides
    the default project.

    You can provide the public key directly or use file() function
    to read from a file.

    Example:
    ```hcl
    ssh_keys = {
      admin_key = {
        name       = "admin-laptop"
        public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... admin@example.com"
      }
      ci_key = {
        name       = "gitlab-ci"
        public_key = file("~/.ssh/gitlab-ci.pub")
        disabled   = false
      }
    }
    ```

    SECURITY NOTES:
    - Use Ed25519 or RSA 4096-bit keys
    - Protect private keys with passphrases
    - Rotate keys regularly
    - Remove unused keys promptly
  EOT
  type = map(object({
    name       = string
    public_key = string
    project_id = optional(string)
    disabled   = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.ssh_keys : can(regex("^[a-zA-Z][a-zA-Z0-9_-]{0,62}$", v.name))
    ])
    error_message = "SSH key names must start with a letter and contain only alphanumeric characters, hyphens, and underscores (max 63 chars)."
  }

  validation {
    condition = alltrue([
      for k, v in var.ssh_keys : can(regex("^ssh-(rsa|ed25519|ecdsa)\\s+[A-Za-z0-9+/=]+", v.public_key))
    ])
    error_message = "Public keys must be valid SSH public key format (ssh-rsa, ssh-ed25519, or ssh-ecdsa)."
  }

  validation {
    condition = alltrue([
      for k, v in var.ssh_keys :
      v.project_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", v.project_id))
    ])
    error_message = "project_id must be a valid UUID format."
  }
}
