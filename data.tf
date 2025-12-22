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
# All resources in this module are created within this project.
#
# The project must already exist in the specified organization.
# ==============================================================================

data "scaleway_account_project" "project" {
  name            = var.project_name
  organization_id = var.organization_id
}
