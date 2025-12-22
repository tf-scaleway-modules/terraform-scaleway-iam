# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                              INPUT VARIABLES                                  ║
# ║                                                                                ║
# ║  All configurable parameters for the Scaleway Object Storage module.          ║
# ║  Variables are organized by category with comprehensive validation.           ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Organization & Project
# ------------------------------------------------------------------------------
# Required identifiers for Scaleway resource organization.
# These determine where resources are created and billed.
# ==============================================================================

variable "organization_id" {
  description = <<-EOT
    Scaleway Organization ID.

    The organization is the top-level entity in Scaleway's hierarchy.
    Find this in the Scaleway Console under Organization Settings.

    Format: UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
  EOT
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.organization_id))
    error_message = "Organization ID must be a valid UUID format."
  }
}

variable "project_name" {
  description = <<-EOT
    Scaleway Project name where all resources will be created.

    Projects provide logical isolation within an organization.
    All buckets, objects, and policies will be created in this project.

    Naming rules:
    - Must start with a lowercase letter
    - Can contain lowercase letters, numbers, and hyphens
    - Must be 2-63 characters long
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.project_name))
    error_message = "Project name must be lowercase alphanumeric with hyphens, start with a letter, and be 2-63 characters."
  }
}

# ==============================================================================
# Global Configuration
# ------------------------------------------------------------------------------
# Settings that apply to all resources created by this module.
# ==============================================================================

variable "region" {
  description = <<-EOT
    Scaleway region for object storage.

    Available regions:
    - fr-par: Paris, France (Europe)
    - nl-ams: Amsterdam, Netherlands (Europe)
    - pl-waw: Warsaw, Poland (Europe)

    Choose the region closest to your users for optimal latency.
    Data residency requirements may also influence this choice.
  EOT
  type        = string
  default     = "fr-par"

  validation {
    condition     = contains(["fr-par", "nl-ams", "pl-waw"], var.region)
    error_message = "Region must be one of: fr-par, nl-ams, pl-waw."
  }
}

variable "tags" {
  description = <<-EOT
    Global tags applied to all resources.

    Tags are key-value pairs for organizing and categorizing resources.
    Common uses:
    - Environment identification (environment:production)
    - Cost allocation (team:platform, project:website)
    - Automation (managed-by:terraform)

    Format: Map of strings (e.g., {env = "prod", team = "devops"})
  EOT
  type        = map(string)
  default     = {}
}
