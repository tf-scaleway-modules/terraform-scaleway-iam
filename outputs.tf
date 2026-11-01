# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              MODULE OUTPUTS                                   ║
# ║                                                                                ║
# ║  Exposes resource identifiers and computed values for use by other modules    ║
# ║  or root configurations.                                                       ║
# ║                                                                                ║
# ║  SECURITY NOTES:                                                              ║
# ║  - Only api_key_secret_keys (secret keys) and user_details (emails) are       ║
# ║    sensitive; every other output is free of secrets and PII                   ║
# ║  - A secret key stays out of the state when its API key sets secret_id        ║
# ║  - Terraform state contains sensitive values - encrypt at rest               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

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
  value       = { for k, v in scaleway_iam_application.this : k => v.id }
}

# ==============================================================================
# API Key Outputs
# ------------------------------------------------------------------------------
# SECURITY: the secret keys are split from the rest of the API key data so that
# api_keys can stay readable. A key that sets secret_id has no secret key in
# state or outputs: it is read from the Secret Manager secret.
# ==============================================================================

output "api_keys" {
  description = <<-EOT
    Map of all created IAM API keys (no secret key).

    Each entry contains:
    - id: The API key's unique identifier
    - access_key: The access key (public part)
    - description: The API key's description
    - created_at: Creation timestamp
    - expires_at: Expiration timestamp (if set)

    The secret key is never part of this output: read it from
    api_key_secret_keys, or, for a key that sets secret_id, from the Secret
    Manager secret (for example with scaleway_secret_version).
  EOT
  value = {
    for k, v in scaleway_iam_api_key.this : k => {
      id          = v.id
      access_key  = v.access_key
      description = v.description
      created_at  = v.created_at
      expires_at  = v.expires_at
    }
  }
}

output "api_key_secret_keys" {
  description = <<-EOT
    Map of API key keys to their secret key (SENSITIVE).

    Only the keys WITHOUT secret_id appear here, and their secret key is
    stored in the Terraform state. A key that sets secret_id is absent: its
    secret key is in neither the state nor any output, read it from the Secret
    Manager secret (for example with scaleway_secret_version).

    Handle with extreme care: never log these values, rotate keys regularly.
  EOT
  value = {
    for k, v in scaleway_iam_api_key.this : k => v.secret_key if v.secret_id == null
  }
  sensitive = true
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
  value       = { for k, v in scaleway_iam_group.this : k => v.id }
}

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
  value       = { for k, v in scaleway_iam_policy.this : k => v.id }
}

# ==============================================================================
# User Outputs
# ------------------------------------------------------------------------------
# SECURITY: User email addresses are PII. They are kept out of `users` and only
# exposed by `user_details`, which is marked sensitive.
# ==============================================================================

output "users" {
  description = <<-EOT
    Map of all created IAM users (non-sensitive, no email address).

    Each entry contains:
    - id: The user's unique identifier
    - created_at: Creation timestamp
    - updated_at: Last update timestamp
    - status: The user's account status
    - type: The user's type (owner, guest, etc.)
    - mfa: Whether the user has enabled multi-factor authentication
    - locked: Whether the user is locked

    Note: Email addresses are excluded from this output.
    Use the sensitive user_details output if you need email addresses.
  EOT
  value = {
    for k, v in scaleway_iam_user.this : k => {
      id         = v.id
      created_at = v.created_at
      updated_at = v.updated_at
      status     = v.status
      type       = v.type
      mfa        = v.mfa
      locked     = v.locked
    }
  }
}

output "user_ids" {
  description = "Map of user keys to their IDs for easy lookup."
  value       = { for k, v in scaleway_iam_user.this : k => v.id }
}

output "user_details" {
  description = <<-EOT
    Full user details including PII (SENSITIVE).

    Contains email addresses - handle according to privacy regulations.
  EOT
  value = {
    for k, v in scaleway_iam_user.this : k => {
      id            = v.id
      email         = v.email
      username      = v.username
      created_at    = v.created_at
      updated_at    = v.updated_at
      deletable     = v.deletable
      last_login_at = v.last_login_at
      status        = v.status
      type          = v.type
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

    Note: Public keys are not included in this output; they are your own
    input.
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

# ==============================================================================
# Security Audit Outputs
# ==============================================================================

output "security_audit" {
  description = <<-EOT
    Security-relevant information for auditing.

    Lists of input map keys:
    - api_keys_without_expiration: API keys without expires_at (security risk)
    - api_keys_with_expiration: every API key that has an expires_at, whatever
      the date (it is not a time window)
    - api_keys_secret_in_state: API keys without secret_id (their secret key
      is stored in the state)
    - users_without_mfa: users whose mfa is not enabled
    - disabled_ssh_keys: SSH keys with disabled = true
    - active_ssh_keys: SSH keys with disabled = false
  EOT
  value = {
    api_keys_without_expiration = [
      for k, v in scaleway_iam_api_key.this : k if v.expires_at == null
    ]
    api_keys_with_expiration = [
      for k, v in scaleway_iam_api_key.this : k if v.expires_at != null
    ]
    api_keys_secret_in_state = [
      for k, v in scaleway_iam_api_key.this : k if v.secret_id == null
    ]
    users_without_mfa = [
      for k, v in scaleway_iam_user.this : k if !v.mfa
    ]
    disabled_ssh_keys = [
      for k, v in scaleway_iam_ssh_key.this : k if v.disabled
    ]
    active_ssh_keys = [
      for k, v in scaleway_iam_ssh_key.this : k if !v.disabled
    ]
  }
}
