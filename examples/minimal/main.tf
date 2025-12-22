# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                     MINIMAL EXAMPLE - SCALEWAY IAM MODULE                     ║
# ║                                                                                ║
# ║  This example demonstrates the simplest use case of the Scaleway IAM module:  ║
# ║  - Single application with API key for Terraform automation                   ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# Variables for the example
# ==============================================================================

variable "organization_id" {
  description = "Your Scaleway Organization ID"
  type        = string
}

variable "project_name" {
  description = "Your Scaleway Project name"
  type        = string
}

# ==============================================================================
# IAM Module - Minimal Configuration
# ==============================================================================

module "iam" {
  source = "../.."

  organization_id = var.organization_id
  project_name    = var.project_name

  # Global tags
  tags = ["managed-by:terraform"]

  # Security settings (disable protection for development)
  enable_deletion_protection = false

  # Create a single application for Terraform automation
  applications = {
    terraform = {
      name        = "terraform"
      description = "Terraform automation"
    }
  }

  # Create an API key for the application
  api_keys = {
    terraform_key = {
      application_key = "terraform"
      description     = "Terraform API key"
    }
  }
}
