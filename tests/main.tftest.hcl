# Unit tests: plan only, mocked provider, no Scaleway account needed.

mock_provider "scaleway" {
  # The provider validates that referenced IDs are UUIDs
  mock_resource "scaleway_iam_application" {
    defaults = {
      id = "33333333-3333-4333-8333-333333333333"
    }
  }

  mock_resource "scaleway_iam_group" {
    defaults = {
      id = "44444444-4444-4444-8444-444444444444"
    }
  }

  mock_data "scaleway_account_project" {
    defaults = {
      id = "99999999-9999-4999-8999-999999999999"
    }
  }
}

variables {
  organization_id = "11111111-1111-4111-8111-111111111111"
}

run "happy_path" {
  command = plan

  variables {
    project_name = "my-project"
    applications = {
      terraform = { name = "terraform" }
      cicd      = { name = "cicd" }
    }
    api_keys = {
      tf = { application_key = "terraform" }
    }
    groups = {
      devs = {
        name             = "devs"
        application_keys = ["cicd"]
        user_ids         = ["12345678-1234-4234-8234-123456789012", "87654321-1234-4234-8234-123456789012"]
      }
    }
    policies = {
      dev = {
        name       = "dev"
        group_keys = ["devs"]
        rules      = [{ permission_set_names = ["IAMReadOnly"] }]
      }
    }
    ssh_keys = {
      laptop = { name = "laptop", public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIabc" }
    }
  }

  assert {
    condition     = length(scaleway_iam_application.this) == 2 && length(scaleway_iam_api_key.this) == 1 && length(scaleway_iam_group.this) == 1 && length(scaleway_iam_policy.this) == 1 && length(scaleway_iam_ssh_key.this) == 1
    error_message = "One resource per map entry expected"
  }

  assert {
    condition     = length(scaleway_iam_group_membership.applications) == 1 && contains(keys(scaleway_iam_group_membership.users), "devs-user-12345678") && length(scaleway_iam_group_membership.users) == 2
    error_message = "Membership keys must be <group>-app-<key> and <group>-user-<8 chars>"
  }

  assert {
    condition     = scaleway_iam_ssh_key.this["laptop"].project_id == "99999999-9999-4999-8999-999999999999"
    error_message = "SSH key must default to the project resolved from project_name"
  }
}

run "guards_enabled_by_default" {
  command = plan

  variables {
    applications = { terraform = { name = "terraform" } }
    groups       = { devs = { name = "devs" } }
    policies = {
      dev = { name = "dev", no_principal = true, rules = [{ permission_set_names = ["IAMReadOnly"] }] }
    }
  }

  assert {
    condition     = length(terraform_data.application_deletion_protection) == 1 && length(terraform_data.group_deletion_protection) == 1 && length(terraform_data.policy_deletion_protection) == 1
    error_message = "One guard per application, group and policy expected"
  }
}

run "guards_disabled" {
  command = plan

  variables {
    enable_deletion_protection = false
    applications               = { terraform = { name = "terraform" } }
    groups                     = { devs = { name = "devs" } }
    policies = {
      dev = { name = "dev", no_principal = true, rules = [{ permission_set_names = ["IAMReadOnly"] }] }
    }
  }

  assert {
    condition     = length(terraform_data.application_deletion_protection) + length(terraform_data.group_deletion_protection) + length(terraform_data.policy_deletion_protection) == 0
    error_message = "No guard expected when protection is disabled"
  }
}

run "api_key_unknown_application" {
  command = plan

  variables {
    api_keys = { k = { application_key = "missing" } }
  }

  expect_failures = [var.api_keys]
}

run "group_unknown_application" {
  command = plan

  variables {
    groups = { devs = { name = "devs", application_keys = ["missing"] } }
  }

  expect_failures = [var.groups]
}

run "group_user_id_prefix_collision" {
  command = plan

  variables {
    groups = {
      devs = {
        name     = "devs"
        user_ids = ["12345678-1234-4234-8234-123456789012", "12345678-9999-4999-8999-999999999999"]
      }
    }
  }

  expect_failures = [var.groups]
}

run "external_membership_lists_not_checked" {
  command = plan

  variables {
    groups = {
      ext = {
        name                = "ext"
        external_membership = true
        application_keys    = ["missing"]
        user_ids            = ["12345678-1234-4234-8234-123456789012", "12345678-9999-4999-8999-999999999999"]
      }
    }
  }

  assert {
    condition     = length(scaleway_iam_group.this) == 1 && length(scaleway_iam_group_membership.users) == 0 && length(scaleway_iam_group_membership.applications) == 0
    error_message = "External membership groups must create no membership and skip the reference checks"
  }
}

run "policy_unknown_group" {
  command = plan

  variables {
    policies = {
      p = { name = "p", group_keys = ["missing"], rules = [{ permission_set_names = ["IAMReadOnly"] }] }
    }
  }

  expect_failures = [var.policies]
}

run "policy_unknown_application" {
  command = plan

  variables {
    policies = {
      p = { name = "p", application_keys = ["missing"], rules = [{ permission_set_names = ["IAMReadOnly"] }] }
    }
  }

  expect_failures = [var.policies]
}

run "policy_unused_unknown_entry_accepted" {
  command = plan

  variables {
    groups = { admins = { name = "admins" } }
    policies = {
      p = {
        name       = "p"
        group_keys = ["admins", "missing"]
        rules      = [{ permission_set_names = ["IAMReadOnly"] }]
      }
    }
  }

  assert {
    condition     = length(scaleway_iam_policy.this) == 1
    error_message = "Unused unknown entries must not fail the plan"
  }

  expect_failures = [check.policy_single_principal]
}

run "policy_ignored_principals_warn_several_lists" {
  command = plan

  variables {
    groups       = { admins = { name = "admins" } }
    applications = { terraform = { name = "terraform" } }
    policies = {
      p = {
        name             = "p"
        group_keys       = ["admins"]
        application_keys = ["terraform"]
        rules            = [{ permission_set_names = ["IAMReadOnly"] }]
      }
    }
  }

  expect_failures = [check.policy_single_principal]
}

run "policy_template_with_principals_warns" {
  command = plan

  variables {
    groups = { admins = { name = "admins" } }
    policies = {
      p = {
        name         = "p"
        no_principal = true
        group_keys   = ["admins"]
        rules        = [{ permission_set_names = ["IAMReadOnly"] }]
      }
    }
  }

  expect_failures = [check.policy_single_principal]
}

run "policy_single_principal_no_warning" {
  command = plan

  variables {
    groups = { admins = { name = "admins" } }
    policies = {
      p  = { name = "p", group_keys = ["admins"], rules = [{ permission_set_names = ["IAMReadOnly"] }] }
      tp = { name = "tp", no_principal = true, rules = [{ permission_set_names = ["IAMReadOnly"] }] }
    }
  }

  assert {
    condition     = length(local.policies_with_ignored_principals) == 0
    error_message = "Single-principal policies and templates must not be reported"
  }
}

run "ssh_key_without_project" {
  command = plan

  variables {
    ssh_keys = {
      laptop = { name = "laptop", public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIabc" }
    }
  }

  expect_failures = [var.ssh_keys]
}

run "ssh_key_with_own_project_and_no_project_name" {
  command = plan

  variables {
    ssh_keys = {
      laptop = {
        name       = "laptop"
        public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIabc"
        project_id = "22222222-2222-4222-8222-222222222222"
      }
    }
  }

  assert {
    condition     = scaleway_iam_ssh_key.this["laptop"].project_id == "22222222-2222-4222-8222-222222222222"
    error_message = "SSH key must use its own project_id"
  }
}
