# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                     COMPLETE EXAMPLE - SCALEWAY IAM MODULE                    ║
# ║                                                                                ║
# ║  This example demonstrates all features of the Scaleway IAM module:           ║
# ║  - Applications (service accounts)                                            ║
# ║  - API Keys with expiration                                                    ║
# ║  - Groups with memberships                                                     ║
# ║  - Policies with organization and project-level rules                         ║
# ║  - Users with invitation settings                                             ║
# ║  - SSH Keys                                                                    ║
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
# Data Sources
# ==============================================================================
# Look up the project to get the project_id for policy rules

data "scaleway_account_project" "this" {
  name            = var.project_name
  organization_id = var.organization_id
}

# ==============================================================================
# IAM Module - Complete Configuration
# ==============================================================================

module "iam" {
  source = "../.."

  organization_id = var.organization_id
  project_name    = var.project_name

  # Global tags applied to all resources
  # Note: Scaleway tags cannot contain colons, use = or _ instead
  tags = [
    "environment=production",
    "managed-by=terraform",
    "example=complete"
  ]

  # ---------------------------------------------------------------------------
  # Security Configuration
  # ---------------------------------------------------------------------------
  # Production security settings

  enable_deletion_protection  = true  # Prevent accidental deletion
  require_api_key_expiration  = false # Set to true in production
  api_key_max_expiration_days = 365   # Max 1 year validity

  # ---------------------------------------------------------------------------
  # Applications (Service Accounts)
  # ---------------------------------------------------------------------------
  # Create service accounts for automation and CI/CD pipelines

  applications = {
    terraform = {
      name        = "terraform-automation"
      description = "Terraform/OpenTofu infrastructure automation"
      tags        = ["automation", "infrastructure"]
    }

    gitlab_ci = {
      name        = "gitlab-ci-pipeline"
      description = "GitLab CI/CD deployment pipeline"
      tags        = ["cicd", "gitlab"]
    }

    monitoring = {
      name        = "monitoring-service"
      description = "Monitoring and observability service"
      tags        = ["monitoring", "readonly"]
    }

    backup = {
      name        = "backup-service"
      description = "Automated backup service"
      tags        = ["backup", "automation"]
    }
  }

  # ---------------------------------------------------------------------------
  # API Keys
  # ---------------------------------------------------------------------------
  # Create API keys for applications with appropriate expiration

  api_keys = {
    terraform_key = {
      application_key    = "terraform"
      description        = "Terraform automation API key"
      default_project_id = data.scaleway_account_project.this.id
      # No expiration for long-running automation
    }

    gitlab_ci_key = {
      application_key    = "gitlab_ci"
      description        = "GitLab CI deployment key"
      default_project_id = data.scaleway_account_project.this.id
      expires_at         = "2026-12-31T23:59:59Z"
    }

    monitoring_key = {
      application_key    = "monitoring"
      description        = "Monitoring service read-only key"
      default_project_id = data.scaleway_account_project.this.id
      expires_at         = "2026-06-30T23:59:59Z"
    }

    backup_key = {
      application_key = "backup"
      description     = "Backup service API key"
      expires_at      = "2026-12-31T23:59:59Z"
    }
  }

  # ---------------------------------------------------------------------------
  # Groups
  # ---------------------------------------------------------------------------
  # Organize users and applications by role

  groups = {
    admins = {
      name             = "organization-admins"
      description      = "Full administrative access to all resources"
      tags             = ["admin", "privileged"]
      application_keys = ["terraform"]
    }

    developers = {
      name             = "developers"
      description      = "Development team with project-level access"
      tags             = ["development"]
      application_keys = ["gitlab_ci"]
    }

    readonly = {
      name             = "readonly-users"
      description      = "Read-only access for monitoring and auditing"
      tags             = ["readonly", "audit"]
      application_keys = ["monitoring"]
    }

    backup_operators = {
      name             = "backup-operators"
      description      = "Backup and restore operations"
      tags             = ["backup", "operations"]
      application_keys = ["backup"]
    }
  }

  # ---------------------------------------------------------------------------
  # Policies
  # ---------------------------------------------------------------------------
  # Define access permissions for groups

  policies = {
    admin_full_access = {
      name        = "admin-full-access"
      description = "Full administrative access to all organization resources"
      group_keys  = ["admins"]
      tags        = ["admin", "full-access"]
      rules = [
        {
          permission_set_names = ["AllProductsFullAccess"]
          organization_id      = var.organization_id
        }
      ]
    }

    developer_project_access = {
      name        = "developer-project-access"
      description = "Developer access to specific projects"
      group_keys  = ["developers"]
      tags        = ["developer", "project-access"]
      rules = [
        {
          permission_set_names = [
            "InstancesFullAccess",
            "ContainersFullAccess",
            "ObjectStorageFullAccess",
            "RelationalDatabasesFullAccess"
          ]
          project_ids = [data.scaleway_account_project.this.id]
        }
      ]
    }

    readonly_organization = {
      name        = "readonly-organization"
      description = "Read-only access to organization resources"
      group_keys  = ["readonly"]
      tags        = ["readonly"]
      rules = [
        {
          permission_set_names = ["AllProductsReadOnly"]
          organization_id      = var.organization_id
        }
      ]
    }

    backup_access = {
      name        = "backup-storage-access"
      description = "Access for backup operations on Object Storage"
      group_keys  = ["backup_operators"]
      tags        = ["backup", "storage"]
      rules = [
        {
          permission_set_names = ["ObjectStorageFullAccess"]
          project_ids          = [data.scaleway_account_project.this.id]
        }
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # Users (Optional - uncomment to invite users)
  # ---------------------------------------------------------------------------
  # Note: Creating users sends invitation emails

  # users = {
  #   admin = {
  #     email               = "admin@example.com"
  #     username            = "admin"
  #     tags                = ["admin"]
  #     send_welcome_email  = true
  #     send_password_email = true
  #   }
  #
  #   developer = {
  #     email               = "developer@example.com"
  #     username            = "developer"
  #     tags                = ["developer"]
  #     send_welcome_email  = true
  #     send_password_email = true
  #   }
  # }

  # ---------------------------------------------------------------------------
  # SSH Keys
  # ---------------------------------------------------------------------------
  # SSH keys for Instance access

  ssh_keys = {
    admin_key = {
      name       = "admin-workstation"
      public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGk2xmMQnPM0XPxrwJGhLhmEHJnLlHjWwBkXxoYkMvy5 admin@example.com"
      disabled   = false
    }

    ci_deploy_key = {
      name       = "gitlab-ci-deploy"
      public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHUzjJHLXtGqIWPQGMvaRWYYWDMRVGNZLJzgNc4VO1Yf gitlab-ci@example.com"
      disabled   = false
    }

    emergency_access = {
      name       = "emergency-access"
      public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPkBEDKDj8qjGPnGbyuLpH8MsP6dtu0sftGmSYJLFkdR emergency@example.com"
      # IMPORTANT: Scaleway API requires SSH keys to be created with disabled=false first.
      # To disable this key after creation:
      # 1. Apply with disabled = false (creates the key)
      # 2. Change to disabled = true and apply again (disables the key)
      disabled = true # Key is now disabled (only works after initial creation)
    }
  }
}
