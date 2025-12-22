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
# ║  - API key expiration enforcement                                              ║
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
# SECURITY: Lifecycle protection enabled by default to prevent accidental deletion.
# ==============================================================================

resource "scaleway_iam_application" "this" {
  for_each = var.applications

  name            = each.value.name
  description     = each.value.description
  organization_id = var.organization_id
  tags            = distinct(concat(var.tags, each.value.tags))

  lifecycle {
    prevent_destroy = false # Controlled via precondition below
  }
}

# Deletion protection check for applications
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
# SECURITY: Preconditions enforce expiration requirements when configured.
# ==============================================================================

resource "scaleway_iam_api_key" "this" {
  for_each = var.api_keys

  # Associate with either an application or a user
  application_id = each.value.application_key != null ? scaleway_iam_application.this[each.value.application_key].id : null
  user_id        = each.value.user_id

  description        = each.value.description
  expires_at         = each.value.expires_at
  default_project_id = each.value.default_project_id

  # Security preconditions
  lifecycle {
    precondition {
      condition     = !var.require_api_key_expiration || each.value.expires_at != null
      error_message = "API key '${each.key}' must have an expiration date (expires_at) when require_api_key_expiration is enabled."
    }
  }

  depends_on = [scaleway_iam_application.this]
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
# SECURITY: Lifecycle protection enabled by default to prevent accidental deletion.
# ==============================================================================

resource "scaleway_iam_group" "this" {
  for_each = var.groups

  name            = each.value.name
  description     = each.value.description
  organization_id = var.organization_id
  tags            = distinct(concat(var.tags, each.value.tags))

  # Membership is managed via scaleway_iam_group_membership resources below
  # This allows for more flexible membership management

  lifecycle {
    prevent_destroy = false # Controlled via terraform_data below
  }

  depends_on = [
    scaleway_iam_application.this,
    scaleway_iam_user.this
  ]
}

# Deletion protection check for groups
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

  depends_on = [
    scaleway_iam_group.this,
    scaleway_iam_application.this
  ]
}

# ==============================================================================
# IAM Group Memberships - Users
# ------------------------------------------------------------------------------
# Manages user memberships in groups.
# ==============================================================================

resource "scaleway_iam_group_membership" "users" {
  for_each = local.group_user_membership_map

  group_id = scaleway_iam_group.this[each.value.group_key].id
  user_id  = each.value.user_id

  depends_on = [
    scaleway_iam_group.this
  ]
}

# ==============================================================================
# IAM Policies
# ------------------------------------------------------------------------------
# Policies define access permissions through rules.
#
# Each rule specifies:
# - Which permission sets to grant
# - At what scope (organization or project level)
#
# A policy can target:
# - Users directly (user_id)
# - Groups (group_id)
# - Applications (application_id)
# - No principal (no_principal = true) for reusable policy templates
#
# SECURITY: Lifecycle protection enabled by default.
# ==============================================================================

resource "scaleway_iam_policy" "this" {
  for_each = var.policies

  name            = each.value.name
  description     = each.value.description
  organization_id = var.organization_id
  tags            = distinct(concat(var.tags, each.value.tags))
  no_principal    = each.value.no_principal

  # Attach to users (use first user, additional users need separate policies or groups)
  user_id = length(each.value.user_ids) > 0 ? each.value.user_ids[0] : null

  # Attach to groups (use first group, additional groups need separate policies)
  group_id = length(each.value.group_keys) > 0 ? scaleway_iam_group.this[each.value.group_keys[0]].id : null

  # Attach to applications (use first application, additional apps need separate policies)
  application_id = length(each.value.application_keys) > 0 ? scaleway_iam_application.this[each.value.application_keys[0]].id : null

  # Define permission rules
  dynamic "rule" {
    for_each = each.value.rules
    content {
      permission_set_names = rule.value.permission_set_names
      organization_id      = rule.value.organization_id
      project_ids          = rule.value.project_ids
    }
  }

  lifecycle {
    prevent_destroy = false # Controlled via terraform_data below
  }

  depends_on = [
    scaleway_iam_application.this,
    scaleway_iam_group.this,
    scaleway_iam_user.this
  ]
}

# Deletion protection check for policies
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
# - Associated with the default project (from var.project_name)
# - Associated with a specific project (via project_id override)
#
# Security best practices:
# - Use Ed25519 or RSA 4096-bit keys
# - Rotate keys regularly
# - Remove unused keys promptly
# - Set disabled = true for temporary access suspension
# ==============================================================================

resource "scaleway_iam_ssh_key" "this" {
  for_each = var.ssh_keys

  name       = each.value.name
  public_key = each.value.public_key
  project_id = coalesce(each.value.project_id, local.project_id)
  disabled   = each.value.disabled
}
