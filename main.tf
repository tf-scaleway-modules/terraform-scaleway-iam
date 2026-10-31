# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              IAM RESOURCES                                    ║
# ║                                                                                ║
# ║  Comprehensive Scaleway IAM management including:                             ║
# ║  - Applications (service accounts)                                            ║
# ║  - API Keys                                                                    ║
# ║  - Groups and Memberships                                                      ║
# ║  - Policies with Rules                                                         ║
# ║  - Users                                                                       ║
# ║  - SSH Keys                                                                    ║
# ║                                                                                ║
# ║  SECURITY FEATURES:                                                           ║
# ║  - Lifecycle protection for critical resources                                 ║
# ║  - API key expiration and secret_id enforcement (secret_id by default)        ║
# ║  - Preconditions for security validation                                       ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# IAM Applications
# ------------------------------------------------------------------------------
# Applications provide identity for non-human users such as CI/CD pipelines,
# Terraform automation, or backend services.
#
# Each application can have associated API keys and be assigned to groups
# and policies for permission management.
#
# SECURITY: A terraform_data guard (prevent_destroy) is created by default to
# block accidental deletion. See var.enable_deletion_protection to lift it.
# ==============================================================================

resource "scaleway_iam_application" "this" {
  for_each = var.applications

  name            = each.value.name
  description     = each.value.description
  organization_id = var.organization_id
  tags            = distinct(concat(var.tags, each.value.tags))
}

# Deletion protection guard for applications
resource "terraform_data" "application_deletion_protection" {
  for_each = var.enable_deletion_protection ? var.applications : {}

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [scaleway_iam_application.this]
}

# ==============================================================================
# IAM API Keys
# ------------------------------------------------------------------------------
# API keys authenticate programmatic access to Scaleway APIs.
#
# Keys can be associated with either:
# - Applications (recommended for automation)
# - Users (for personal scripts)
#
# Security best practices:
# - Set expiration dates for time-limited access
# - Use application keys over user keys when possible
# - Rotate keys regularly
#
# SECURITY: Preconditions enforce expiration and secret_id requirements when
# configured. With secret_id set, the secret key is stored in Secret Manager
# and never reaches the state.
# ==============================================================================

resource "scaleway_iam_api_key" "this" {
  for_each = var.api_keys

  # Associate with either an application or a user
  application_id = each.value.application_key != null ? scaleway_iam_application.this[each.value.application_key].id : null
  user_id        = each.value.user_id

  description        = each.value.description
  expires_at         = each.value.expires_at
  default_project_id = each.value.default_project_id != null ? each.value.default_project_id : var.project_id

  # Secret Manager secret receiving the secret key (kept out of state when set)
  secret_id = each.value.secret_id

  # Security preconditions
  lifecycle {
    precondition {
      condition     = !var.require_api_key_expiration || each.value.expires_at != null
      error_message = "API key '${each.key}' must have an expiration date (expires_at) when require_api_key_expiration is enabled."
    }

    precondition {
      condition     = !var.require_api_key_secret_id || each.value.secret_id != null
      error_message = "API key '${each.key}' must set secret_id when require_api_key_secret_id is enabled."
    }
  }
}

# ==============================================================================
# IAM Groups
# ------------------------------------------------------------------------------
# Groups organize users and applications for collective permission management.
#
# Best practices:
# - Attach policies to groups rather than individual identities
# - Organize groups by role or function
# - Use descriptive names that indicate the group's purpose
#
# SECURITY: A terraform_data guard (prevent_destroy) is created by default to
# block accidental deletion. See var.enable_deletion_protection to lift it.
# ==============================================================================

resource "scaleway_iam_group" "this" {
  for_each = var.groups

  name            = each.value.name
  description     = each.value.description
  organization_id = var.organization_id
  tags            = distinct(concat(var.tags, each.value.tags))

  # Members come from the scaleway_iam_group_membership resources below: the
  # provider must neither write nor read them on the group itself.
  external_membership = true
}

# Deletion protection guard for groups
resource "terraform_data" "group_deletion_protection" {
  for_each = var.enable_deletion_protection ? var.groups : {}

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [scaleway_iam_group.this]
}

# ==============================================================================
# IAM Group Memberships - Applications
# ------------------------------------------------------------------------------
# Manages application memberships in groups.
# ==============================================================================

resource "scaleway_iam_group_membership" "applications" {
  for_each = local.group_application_membership_map

  group_id       = scaleway_iam_group.this[each.value.group_key].id
  application_id = scaleway_iam_application.this[each.value.application_key].id
}

# ==============================================================================
# IAM Group Memberships - Users
# ------------------------------------------------------------------------------
# Manages user memberships in groups: existing users by ID (user_ids) and
# users created by this module by key (user_keys), known in the same apply.
# ==============================================================================

resource "scaleway_iam_group_membership" "users" {
  for_each = local.group_user_membership_map

  group_id = scaleway_iam_group.this[each.value.group_key].id
  user_id  = each.value.user_key != null ? scaleway_iam_user.this[each.value.user_key].id : each.value.user_id
}

# ==============================================================================
# IAM Policies
# ------------------------------------------------------------------------------
# Policies define access permissions through rules.
#
# Each rule specifies:
# - Which permission sets to grant
# - At what scope (organization or project level)
# - An optional condition (CEL expression)
#
# A policy has exactly one principal (validated on var.policies):
# - A user (user_id)
# - A group (group_key)
# - An application (application_key)
# - No principal (no_principal = true) for reusable policy templates
#
# SECURITY: A terraform_data guard (prevent_destroy) is created by default to
# block accidental deletion. See var.enable_deletion_protection to lift it.
# ==============================================================================

resource "scaleway_iam_policy" "this" {
  for_each = var.policies

  name            = each.value.name
  description     = each.value.description
  organization_id = var.organization_id
  tags            = distinct(concat(var.tags, each.value.tags))

  # The provider requires exactly one of these four, as does the variable validation
  user_id        = each.value.user_id
  group_id       = each.value.group_key != null ? scaleway_iam_group.this[each.value.group_key].id : null
  application_id = each.value.application_key != null ? scaleway_iam_application.this[each.value.application_key].id : null
  no_principal   = each.value.no_principal ? true : null

  dynamic "rule" {
    for_each = each.value.rules
    content {
      permission_set_names = rule.value.permission_set_names
      organization_id      = rule.value.organization_wide ? var.organization_id : null
      project_ids          = rule.value.project_ids
      condition            = rule.value.condition
    }
  }
}

# Deletion protection guard for policies
resource "terraform_data" "policy_deletion_protection" {
  for_each = var.enable_deletion_protection ? var.policies : {}

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [scaleway_iam_policy.this]
}

# ==============================================================================
# IAM Users
# ------------------------------------------------------------------------------
# Users represent human identities in the organization.
#
# IMPORTANT: Creating a user sends an invitation email to the specified address.
# The user must accept the invitation to activate their account.
#
# For programmatic/automated access, prefer applications over users.
# ==============================================================================

resource "scaleway_iam_user" "this" {
  for_each = var.users

  email               = each.value.email
  username            = each.value.username
  organization_id     = var.organization_id
  tags                = distinct(concat(var.tags, each.value.tags))
  send_password_email = each.value.send_password_email
  send_welcome_email  = each.value.send_welcome_email
}

# ==============================================================================
# IAM SSH Keys
# ------------------------------------------------------------------------------
# SSH keys provide secure access to Scaleway Instances and other resources.
#
# Keys are project-scoped and can be:
# - Associated with the default project (var.project_id)
# - Associated with a specific project (via project_id override)
#
# Security best practices:
# - Use Ed25519 or RSA 4096-bit keys
# - Rotate keys regularly
# - Remove unused keys promptly
# - Set disabled = true for temporary access suspension
#
# IMPORTANT - DISABLED SSH KEYS:
# The Scaleway API does not support creating SSH keys with disabled = true.
# Keys must be created first (disabled = false), then disabled on a subsequent
# apply (disabled = true). This is a Scaleway API limitation.
#
# Workflow for disabled keys:
# 1. First apply:  Set disabled = false -> Key is created
# 2. Second apply: Set disabled = true  -> Key is disabled
# ==============================================================================

resource "scaleway_iam_ssh_key" "this" {
  for_each = var.ssh_keys

  name       = each.value.name
  public_key = each.value.public_key
  project_id = each.value.project_id != null ? each.value.project_id : var.project_id
  disabled   = each.value.disabled
}
