# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              LOCAL VALUES                                     ║
# ║                                                                                ║
# ║  Computed values and transformations used throughout the module.              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

locals {
  # ==============================================================================
  # Group Membership Flattening
  # ------------------------------------------------------------------------------
  # Flattens group memberships for use with scaleway_iam_group_membership.
  # Membership keys: <group>-app-<application key>, <group>-user-<8 chars of the
  # user ID> and <group>-user-key-<user key> (a hyphen never appears in the
  # 8-character hexadecimal form, so the two user forms cannot collide).
  # ==============================================================================

  # Flatten application memberships
  group_application_memberships = flatten([
    for group_key, group in var.groups : [
      for app_key in group.application_keys : {
        group_key       = group_key
        application_key = app_key
        membership_key  = "${group_key}-app-${app_key}"
      }
    ]
  ])

  # Flatten user memberships: existing users by ID, module users by key
  group_user_memberships = flatten([
    for group_key, group in var.groups : concat(
      [
        for user_id in group.user_ids : {
          group_key      = group_key
          user_id        = user_id
          user_key       = null
          membership_key = "${group_key}-user-${substr(user_id, 0, 8)}"
        }
      ],
      [
        for user_key in group.user_keys : {
          group_key      = group_key
          user_id        = null
          user_key       = user_key
          membership_key = "${group_key}-user-key-${user_key}"
        }
      ]
    )
  ])

  # Convert to maps for for_each
  group_application_membership_map = {
    for m in local.group_application_memberships : m.membership_key => m
  }

  group_user_membership_map = {
    for m in local.group_user_memberships : m.membership_key => m
  }
}
