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

variable "project_id" {
  description = "Your Scaleway Project ID"
  type        = string
}

variable "secret_id" {
  description = "ID of the Secret Manager secret receiving the API key secret key (UUID or <region>/<uuid>)"
  type        = string
}

# ==============================================================================
# IAM Module - Minimal Configuration
# ==============================================================================

module "iam" {
  source = "../.."

  organization_id = var.organization_id
  project_id      = var.project_id

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

  # Create an API key for the application. Its secret key goes to the Secret
  # Manager secret (required by default) and never reaches the state.
  api_keys = {
    terraform_key = {
      application_key = "terraform"
      description     = "Terraform API key"
      secret_id       = var.secret_id
    }
  }
}
