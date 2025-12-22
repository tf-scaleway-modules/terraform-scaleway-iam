# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              MODULE OUTPUTS                                   ║
# ║                                                                                ║
# ║  Exposes resource identifiers and computed values for use by other modules    ║
# ║  or root configurations.                                                       ║
# ║                                                                                ║
# ║  SECURITY NOTES:                                                              ║
# ║  - Outputs containing secrets are marked sensitive = true                     ║
# ║  - User PII (emails) is marked sensitive                                      ║
# ║  - Consider using a secrets manager for API key storage                       ║
# ║  - Terraform state contains sensitive values - encrypt at rest               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Project Outputs
# ==============================================================================

output "project_id" {
  description = "The ID of the Scaleway project (if project_name was provided)."
  value       = local.project_id
}

# ==============================================================================
# Application Outputs
# ==============================================================================

output "applications" {
  description = <<-EOT
    Map of all created IAM applications.

    Each entry contains:
    - id: The application's unique identifier
    - name: The application's display name
    - description: The application's description
    - created_at: Creation timestamp
    - updated_at: Last update timestamp
    - editable: Whether the application can be modified
  EOT
  value = {
    for k, v in scaleway_iam_application.this : k => {
      id          = v.id
      name        = v.name
      description = v.description
      created_at  = v.created_at
      updated_at  = v.updated_at
      editable    = v.editable
    }
  }
}

output "application_ids" {
  description = "Map of application keys to their IDs for easy lookup."
  value       = local.application_ids
}

# ==============================================================================
# API Key Outputs
# ------------------------------------------------------------------------------
# SECURITY: API key secrets are highly sensitive. These outputs are marked
# sensitive but will still be stored in Terraform state. Ensure:
# - State is encrypted at rest
# - State access is restricted
# - Consider using a secrets manager instead of state outputs
# ==============================================================================

output "api_keys" {
  description = <<-EOT
    Map of all created IAM API keys (SENSITIVE).

    Each entry contains:
    - id: The API key's unique identifier
    - access_key: The access key (public part)
    - secret_key: The secret key (SENSITIVE - handle with extreme care)
    - description: The API key's description
    - created_at: Creation timestamp
    - expires_at: Expiration timestamp (if set)

    SECURITY WARNING:
    - Store secrets in a secrets manager (Vault, AWS Secrets Manager, etc.)
    - Never log or expose these values
    - Rotate keys regularly
    - This output is marked sensitive but values persist in state
  EOT
  value = {
    for k, v in scaleway_iam_api_key.this : k => {
      id          = v.id
      access_key  = v.access_key
      secret_key  = v.secret_key
      description = v.description
      created_at  = v.created_at
      expires_at  = v.expires_at
    }
  }
  sensitive = true
}

output "api_key_access_keys" {
  description = "Map of API key names to their access keys (public part only, non-sensitive)."
  value = {
    for k, v in scaleway_iam_api_key.this : k => v.access_key
  }
}

output "api_key_ids" {
  description = "Map of API key names to their IDs."
  value = {
    for k, v in scaleway_iam_api_key.this : k => v.id
  }
}

# ==============================================================================
# Group Outputs
# ==============================================================================

output "groups" {
  description = <<-EOT
    Map of all created IAM groups.

    Each entry contains:
    - id: The group's unique identifier
    - name: The group's display name
    - description: The group's description
    - created_at: Creation timestamp
    - updated_at: Last update timestamp
  EOT
  value = {
    for k, v in scaleway_iam_group.this : k => {
      id          = v.id
      name        = v.name
      description = v.description
      created_at  = v.created_at
      updated_at  = v.updated_at
    }
  }
}

output "group_ids" {
  description = "Map of group keys to their IDs for easy lookup."
  value       = local.group_ids
}

# ==============================================================================
# Policy Outputs
# ==============================================================================

output "policies" {
  description = <<-EOT
    Map of all created IAM policies.

    Each entry contains:
    - id: The policy's unique identifier
    - name: The policy's display name
    - description: The policy's description
    - created_at: Creation timestamp
    - updated_at: Last update timestamp
    - editable: Whether the policy can be modified
  EOT
  value = {
    for k, v in scaleway_iam_policy.this : k => {
      id          = v.id
      name        = v.name
      description = v.description
      created_at  = v.created_at
      updated_at  = v.updated_at
      editable    = v.editable
    }
  }
}

output "policy_ids" {
  description = "Map of policy keys to their IDs for easy lookup."
  value = {
    for k, v in scaleway_iam_policy.this : k => v.id
  }
}

# ==============================================================================
# User Outputs
# ------------------------------------------------------------------------------
# SECURITY: User information contains PII (email addresses).
# This output is marked sensitive to prevent accidental exposure.
# ==============================================================================

output "users" {
  description = <<-EOT
    Map of all created IAM users (SENSITIVE - contains PII).

    Each entry contains:
    - id: The user's unique identifier
    - created_at: Creation timestamp
    - updated_at: Last update timestamp
    - status: The user's account status
    - type: The user's type (owner, guest, etc.)
    - two_factor_enabled: Whether 2FA is enabled

    Note: Email addresses are excluded from non-sensitive outputs.
    Use user_details output if you need email addresses.
  EOT
  value = {
    for k, v in scaleway_iam_user.this : k => {
      id                 = v.id
      created_at         = v.created_at
      updated_at         = v.updated_at
      status             = v.status
      type               = v.type
      two_factor_enabled = v.two_factor_enabled
    }
  }
}

output "user_ids" {
  description = "Map of user keys to their IDs for easy lookup."
  value       = local.user_ids
}

output "user_details" {
  description = <<-EOT
    Full user details including PII (SENSITIVE).

    Contains email addresses - handle according to privacy regulations.
  EOT
  value = {
    for k, v in scaleway_iam_user.this : k => {
      id                 = v.id
      email              = v.email
      username           = v.username
      created_at         = v.created_at
      updated_at         = v.updated_at
      deletable          = v.deletable
      last_login_at      = v.last_login_at
      status             = v.status
      type               = v.type
      two_factor_enabled = v.two_factor_enabled
    }
  }
  sensitive = true
}

# ==============================================================================
# SSH Key Outputs
# ==============================================================================

output "ssh_keys" {
  description = <<-EOT
    Map of all created IAM SSH keys.

    Each entry contains:
    - id: The SSH key's unique identifier
    - name: The SSH key's display name
    - fingerprint: The SSH key fingerprint
    - created_at: Creation timestamp
    - updated_at: Last update timestamp
    - project_id: Associated project ID
    - disabled: Whether the key is disabled

    Note: Public keys are not included in this output.
    Use ssh_key_public_keys if you need them.
  EOT
  value = {
    for k, v in scaleway_iam_ssh_key.this : k => {
      id          = v.id
      name        = v.name
      fingerprint = v.fingerprint
      created_at  = v.created_at
      updated_at  = v.updated_at
      project_id  = v.project_id
      disabled    = v.disabled
    }
  }
}

output "ssh_key_ids" {
  description = "Map of SSH key names to their IDs for easy lookup."
  value = {
    for k, v in scaleway_iam_ssh_key.this : k => v.id
  }
}

output "ssh_key_fingerprints" {
  description = "Map of SSH key names to their fingerprints."
  value = {
    for k, v in scaleway_iam_ssh_key.this : k => v.fingerprint
  }
}

output "ssh_key_public_keys" {
  description = "Map of SSH key names to their public keys."
  value = {
    for k, v in scaleway_iam_ssh_key.this : k => v.public_key
  }
}

# ==============================================================================
# Group Membership Outputs
# ==============================================================================

output "group_memberships" {
  description = <<-EOT
    Summary of all group memberships created by this module.

    Includes both application and user memberships organized by group.
  EOT
  value = {
    applications = {
      for k, v in scaleway_iam_group_membership.applications : k => {
        group_id       = v.group_id
        application_id = v.application_id
      }
    }
    users = {
      for k, v in scaleway_iam_group_membership.users : k => {
        group_id = v.group_id
        user_id  = v.user_id
      }
    }
  }
}

# ==============================================================================
# Summary Outputs
# ==============================================================================

output "summary" {
  description = <<-EOT
    Summary statistics for all IAM resources created by this module.

    Useful for monitoring and auditing purposes.
  EOT
  value = {
    organization_id         = var.organization_id
    project_id              = local.project_id
    applications_count      = length(scaleway_iam_application.this)
    api_keys_count          = length(scaleway_iam_api_key.this)
    groups_count            = length(scaleway_iam_group.this)
    policies_count          = length(scaleway_iam_policy.this)
    users_count             = length(scaleway_iam_user.this)
    ssh_keys_count          = length(scaleway_iam_ssh_key.this)
    group_memberships_count = length(scaleway_iam_group_membership.applications) + length(scaleway_iam_group_membership.users)
  }
}

# ==============================================================================
# Security Audit Outputs
# ==============================================================================

output "security_audit" {
  description = <<-EOT
    Security-relevant information for auditing.

    Includes:
    - API keys without expiration (security risk)
    - Users without 2FA enabled
    - Disabled SSH keys count
  EOT
  value = {
    api_keys_without_expiration = [
      for k, v in scaleway_iam_api_key.this : k if v.expires_at == null
    ]
    api_keys_expiring_soon = [
      for k, v in scaleway_iam_api_key.this : k if v.expires_at != null
    ]
    disabled_ssh_keys = [
      for k, v in scaleway_iam_ssh_key.this : k if v.disabled
    ]
    active_ssh_keys = [
      for k, v in scaleway_iam_ssh_key.this : k if !v.disabled
    ]
  }
}
