# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              DATA SOURCES                                     ║
# ║                                                                                ║
# ║  External data lookups for existing Scaleway resources.                       ║
# ║  These provide information needed for resource configuration.                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Project Data Source
# ------------------------------------------------------------------------------
# Looks up the Scaleway project by name to get the project ID.
# This is only used when project_name is provided.
#
# SSH keys and some other resources are project-scoped.
# ==============================================================================

data "scaleway_account_project" "project" {
  count = var.project_name != null ? 1 : 0

  name            = var.project_name
  organization_id = var.organization_id
}
