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
  description = "Scaleway Organization ID (UUID), the top-level entity of the Scaleway hierarchy, found in the Console under Organization Settings."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.organization_id))
    error_message = "Organization ID must be a valid UUID format."
  }
}

variable "project_id" {
  description = "Scaleway Project ID (UUID) used as the fallback for `ssh_keys[*].project_id` and `api_keys[*].default_project_id` when they are not set. `null` means the provider default project applies."
  type        = string
  default     = null

  validation {
    condition     = var.project_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.project_id))
    error_message = "project_id must be a valid UUID format."
  }
}

# ==============================================================================
# Global Configuration
# ------------------------------------------------------------------------------
# Settings that apply to all resources created by this module.
# ==============================================================================

variable "tags" {
  description = "Global tags applied to every resource that supports tagging, as a list of strings such as `[\"env=prod\", \"team=devops\"]`. The module does not validate them; the Scaleway API enforces its own tag rules."
  type        = list(string)
  default     = []
}

# ==============================================================================
# Security Configuration
# ------------------------------------------------------------------------------
# Settings that control security behavior of the module.
# ==============================================================================

variable "enable_deletion_protection" {
  description = "Whether a `terraform_data` guard with `prevent_destroy` protects every application, group and policy, so any plan that destroys one fails. Switching it from `true` to `false` on an existing deployment also fails; see Deletion Protection in the README to lift protection."
  type        = bool
  default     = true
}

variable "require_api_key_expiration" {
  description = "Whether the plan fails when an API key is configured without `expires_at`, which enforces credential rotation."
  type        = bool
  default     = false
}

# DEVIATION(terraform-variables): the name follows the released sibling
# require_api_key_expiration instead of the enable_/is_ boolean prefix.
variable "require_api_key_secret_id" {
  description = "Whether the plan fails when an API key is configured without `secret_id`, so that no API key secret lands in the state. Setting `false` opts out and stores those secret keys in the state, exposed by the sensitive `api_key_secret_keys` output."
  type        = bool
  default     = true
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
  description = "Map of IAM applications (service accounts for non-human access) to create, keyed by a stable reference used by `api_keys`, `groups` and `policies`. See Input reference in the README for every attribute."
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
  description = "Map of IAM API keys to create, keyed by a stable reference. Each key sets exactly one of `application_key` or `user_id`; `secret_id` keeps the secret key out of the state and outputs by sending it to Secret Manager. See Input reference in the README for every attribute."
  type = map(object({
    application_key    = optional(string)
    user_id            = optional(string)
    description        = optional(string, "")
    expires_at         = optional(string)
    default_project_id = optional(string)
    secret_id          = optional(string)
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
      v.application_key == null || contains(keys(var.applications), v.application_key)
    ])
    error_message = "application_key must be a key of the applications input."
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
      v.expires_at == null || (can(regex("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$", v.expires_at)) && can(timecmp(v.expires_at, v.expires_at)))
    ])
    error_message = "expires_at must be in ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ)."
  }

  validation {
    condition = alltrue([
      for k, v in var.api_keys :
      v.secret_id == null || can(regex("^([a-z]{2}-[a-z]{3}/)?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", v.secret_id))
    ])
    error_message = "secret_id must be a UUID or a regional ID (<region>/<uuid>)."
  }
}

# ==============================================================================
# IAM Groups
# ------------------------------------------------------------------------------
# Groups organize users and applications for collective permission management.
# Attach policies to groups rather than individual identities when possible.
# ==============================================================================

variable "groups" {
  description = "Map of IAM groups to create, keyed by a stable reference used by `policies`. Members are managed only through `application_keys`, `user_keys` and `user_ids`. See Input reference in the README for every attribute."
  type = map(object({
    name             = string
    description      = optional(string, "")
    tags             = optional(list(string), [])
    application_keys = optional(list(string), [])
    user_keys        = optional(list(string), [])
    user_ids         = optional(list(string), [])
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

  validation {
    condition = alltrue([
      for k, v in var.groups : alltrue([
        for app_key in v.application_keys : contains(keys(var.applications), app_key)
      ])
    ])
    error_message = "Group application_keys must be keys of the applications input."
  }

  validation {
    condition = alltrue([
      for k, v in var.groups : alltrue([
        for user_key in v.user_keys : contains(keys(var.users), user_key)
      ])
    ])
    error_message = "Group user_keys must be keys of the users input."
  }

  # Membership keys use the first 8 characters of the user ID
  validation {
    condition = alltrue([
      for k, v in var.groups :
      length(distinct([for user_id in v.user_ids : substr(user_id, 0, 8)])) == length(v.user_ids)
    ])
    error_message = "user_ids of one group must be unique and must not share their first 8 characters (membership keys are derived from them)."
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
  description = "Map of IAM policies to create, keyed by a stable reference. Each policy has exactly one principal and one or more rules granting permission sets. See Input reference in the README for every attribute."
  type = map(object({
    name            = string
    description     = optional(string, "")
    tags            = optional(list(string), [])
    no_principal    = optional(bool, false)
    user_id         = optional(string)
    group_key       = optional(string)
    application_key = optional(string)
    rules = list(object({
      permission_set_names = list(string)
      organization_wide    = optional(bool, false)
      project_ids          = optional(list(string), [])
      condition            = optional(string)
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
      for k, v in var.policies :
      length(compact([v.user_id, v.group_key, v.application_key])) + (v.no_principal ? 1 : 0) == 1
    ])
    error_message = "Each policy must set exactly one of user_id, group_key, application_key or no_principal = true."
  }

  validation {
    condition = alltrue([
      for k, v in var.policies :
      v.user_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", v.user_id))
    ])
    error_message = "user_id must be a valid UUID format."
  }

  validation {
    condition = alltrue([
      for k, v in var.policies :
      v.group_key == null || contains(keys(var.groups), v.group_key)
    ])
    error_message = "group_key must be a key of the groups input."
  }

  validation {
    condition = alltrue([
      for k, v in var.policies :
      v.application_key == null || contains(keys(var.applications), v.application_key)
    ])
    error_message = "application_key must be a key of the applications input."
  }

  validation {
    condition = alltrue([
      for k, v in var.policies : alltrue([
        for rule in v.rules : !rule.organization_wide || length(rule.project_ids) == 0
      ])
    ])
    error_message = "A rule must not set both organization_wide and project_ids."
  }
}

# ==============================================================================
# IAM Users
# ------------------------------------------------------------------------------
# Users represent human identities in the organization.
# Note: Creating a user sends an invitation email to the specified address.
# ==============================================================================

variable "users" {
  description = "Map of IAM users to invite to the organization, keyed by a stable reference used by `groups[*].user_keys`. Creating a user sends an invitation email. See Input reference in the README for every attribute."
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
  description = "Map of IAM SSH keys to create, keyed by a stable reference. A key cannot be created with `disabled = true`; see Input reference in the README for every attribute and the two-step process."
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
      for k, v in var.ssh_keys : can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp(256|384|521))\\s+[A-Za-z0-9+/=]+", v.public_key))
    ])
    error_message = "Public keys must be valid SSH public key format (ssh-rsa, ssh-ed25519 or ecdsa-sha2-nistp256/384/521)."
  }

  validation {
    condition = alltrue([
      for k, v in var.ssh_keys :
      v.project_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", v.project_id))
    ])
    error_message = "project_id must be a valid UUID format."
  }
}
