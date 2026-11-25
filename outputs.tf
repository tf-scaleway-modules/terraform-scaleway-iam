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
  description = "Map of all created IAM applications, keyed like the `applications` input, with `id`, `name`, `description`, `created_at`, `updated_at` and `editable`."
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
  description = "Map of all created IAM API keys without their secret key, keyed like the `api_keys` input, with `id`, `access_key`, `description`, `created_at` and `expires_at`. The secret key comes from `api_key_secret_keys` or, for a key that sets `secret_id`, from the Secret Manager secret."
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
  description = "Sensitive map of API key references to their secret key, only for keys WITHOUT `secret_id`, whose secret key is stored in the state. A key that sets `secret_id` is absent: read its secret key from the Secret Manager secret."
  value = {
    for k, v in scaleway_iam_api_key.this : k => v.secret_key if v.secret_id == null
  }
  sensitive = true
}

# ==============================================================================
# Group Outputs
# ==============================================================================

output "groups" {
  description = "Map of all created IAM groups, keyed like the `groups` input, with `id`, `name`, `description`, `created_at` and `updated_at`."
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
  description = "Group memberships created by this module, as `applications` and `users` maps whose entries hold the `group_id` and the `application_id` or `user_id`."
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
  description = "Map of all created IAM policies, keyed like the `policies` input, with `id`, `name`, `description`, `created_at`, `updated_at` and `editable`."
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
  description = "Map of all created IAM users without their email address, keyed like the `users` input, with `id`, `created_at`, `updated_at`, `status`, `type`, `mfa` and `locked`. Use the sensitive `user_details` output for email addresses."
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
  description = "Sensitive map of full user details including the email address (PII), keyed like the `users` input. Handle according to privacy regulations."
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
  description = "Map of all created IAM SSH keys, keyed like the `ssh_keys` input, with `id`, `name`, `fingerprint`, `created_at`, `updated_at`, `project_id` and `disabled`. Public keys are not included."
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
  description = "Lists of input map keys for auditing: API keys without and with `expires_at`, API keys whose secret key is stored in the state, users without MFA, and disabled and active SSH keys."
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
