# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              LOCAL VALUES                                     ║
# ║                                                                                ║
# ║  Computed values and transformations used throughout the module.              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

locals {
  # ==============================================================================
  # Project ID Resolution
  # ------------------------------------------------------------------------------
  # Resolves the project ID from the data source when project_name is provided.
  # Returns null if no project_name is specified.
  # ==============================================================================
  project_id = var.project_name != null ? data.scaleway_account_project.project[0].id : null

  # ==============================================================================
  # Resource Mappings
  # ------------------------------------------------------------------------------
  # Helper mappings for cross-referencing resources.
  # ==============================================================================

  # Map of application keys to their IDs
  application_ids = {
    for k, v in scaleway_iam_application.this : k => v.id
  }

  # Map of group keys to their IDs
  group_ids = {
    for k, v in scaleway_iam_group.this : k => v.id
  }

  # Map of user keys to their IDs
  user_ids = {
    for k, v in scaleway_iam_user.this : k => v.id
  }

  # ==============================================================================
  # Group Membership Flattening
  # ------------------------------------------------------------------------------
  # Flattens group memberships for use with scaleway_iam_group_membership.
  # This is an alternative approach if the group resource doesn't support
  # inline membership management.
  # ==============================================================================

  # Flatten application memberships
  group_application_memberships = flatten([
    for group_key, group in var.groups : [
      for app_key in group.application_keys : {
        group_key       = group_key
        application_key = app_key
        membership_key  = "${group_key}-app-${app_key}"
      }
    ] if !group.external_membership
  ])

  # Flatten user memberships
  group_user_memberships = flatten([
    for group_key, group in var.groups : [
      for user_id in group.user_ids : {
        group_key      = group_key
        user_id        = user_id
        membership_key = "${group_key}-user-${substr(user_id, 0, 8)}"
      }
    ] if !group.external_membership
  ])

  # Convert to maps for for_each
  group_application_membership_map = {
    for m in local.group_application_memberships : m.membership_key => m
  }

  group_user_membership_map = {
    for m in local.group_user_memberships : m.membership_key => m
  }
}
