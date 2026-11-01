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

  mock_resource "scaleway_iam_user" {
    defaults = {
      id     = "66666666-6666-4666-8666-666666666666"
      mfa    = false
      locked = false
    }
  }
}

variables {
  organization_id = "11111111-1111-4111-8111-111111111111"
}

run "happy_path" {
  command = plan

  variables {
    project_id = "99999999-9999-4999-8999-999999999999"
    applications = {
      terraform = { name = "terraform" }
      cicd      = { name = "cicd" }
    }
    api_keys = {
      tf = { application_key = "terraform", secret_id = "55555555-5555-4555-8555-555555555555" }
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
        name      = "dev"
        group_key = "devs"
        rules     = [{ permission_set_names = ["IAMReadOnly"] }]
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
    condition     = scaleway_iam_policy.this["dev"].group_id == "44444444-4444-4444-8444-444444444444" && scaleway_iam_policy.this["dev"].user_id == null && scaleway_iam_policy.this["dev"].application_id == null
    error_message = "A group_key policy must be attached to that group only"
  }

  assert {
    condition     = scaleway_iam_ssh_key.this["laptop"].project_id == "99999999-9999-4999-8999-999999999999"
    error_message = "SSH key must default to the module project_id"
  }

  assert {
    condition     = output.group_ids["devs"] == "44444444-4444-4444-8444-444444444444" && length(output.application_ids) == 2 && length(output.policy_ids) == 1
    error_message = "ID outputs must be keyed by the input map keys"
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

# ------------------------------------------------------------------------------
# Project
# ------------------------------------------------------------------------------

run "ssh_key_inherits_project_id" {
  command = plan

  variables {
    project_id = "99999999-9999-4999-8999-999999999999"
    ssh_keys = {
      laptop = { name = "laptop", public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIabc" }
    }
  }

  assert {
    condition     = scaleway_iam_ssh_key.this["laptop"].project_id == "99999999-9999-4999-8999-999999999999"
    error_message = "SSH key without project_id must use the module project_id"
  }

  assert {
    condition     = output.ssh_keys["laptop"].project_id == "99999999-9999-4999-8999-999999999999"
    error_message = "The ssh_keys output must expose the project of the key"
  }
}

run "ssh_key_own_project_wins" {
  command = plan

  variables {
    project_id = "99999999-9999-4999-8999-999999999999"
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

run "no_project_anywhere_plans" {
  command = plan

  variables {
    ssh_keys = {
      laptop = { name = "laptop", public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIabc" }
    }
  }

  assert {
    condition     = length(scaleway_iam_ssh_key.this) == 1
    error_message = "An SSH key without any project must plan (provider default project)"
  }
}

run "api_key_default_project_follows_project_id" {
  command = plan

  variables {
    project_id   = "99999999-9999-4999-8999-999999999999"
    applications = { terraform = { name = "terraform" } }
    api_keys = {
      inherits = {
        application_key = "terraform"
        secret_id       = "55555555-5555-4555-8555-555555555555"
      }
      own = {
        application_key    = "terraform"
        secret_id          = "55555555-5555-4555-8555-555555555555"
        default_project_id = "22222222-2222-4222-8222-222222222222"
      }
    }
  }

  assert {
    condition     = scaleway_iam_api_key.this["inherits"].default_project_id == "99999999-9999-4999-8999-999999999999"
    error_message = "default_project_id must fall back to project_id"
  }

  assert {
    condition     = scaleway_iam_api_key.this["own"].default_project_id == "22222222-2222-4222-8222-222222222222"
    error_message = "An explicit default_project_id must be kept"
  }
}

run "project_id_invalid" {
  command = plan

  variables {
    project_id = "my-project"
  }

  expect_failures = [var.project_id]
}

# ------------------------------------------------------------------------------
# API keys
# ------------------------------------------------------------------------------

run "api_key_unknown_application" {
  command = plan

  variables {
    api_keys = { k = { application_key = "missing" } }
  }

  expect_failures = [var.api_keys]
}

run "api_key_expires_at_impossible_date" {
  command = plan

  variables {
    applications = { terraform = { name = "terraform" } }
    api_keys = {
      k = { application_key = "terraform", expires_at = "2026-13-45T00:00:00Z" }
    }
  }

  expect_failures = [var.api_keys]
}

run "api_key_expires_at_valid_date" {
  command = plan

  variables {
    applications = { terraform = { name = "terraform" } }
    api_keys = {
      k = {
        application_key = "terraform"
        expires_at      = "2026-12-31T23:59:59Z"
        secret_id       = "55555555-5555-4555-8555-555555555555"
      }
    }
  }

  assert {
    condition     = output.security_audit.api_keys_with_expiration == ["k"] && length(output.security_audit.api_keys_without_expiration) == 0
    error_message = "A key with expires_at must be listed in api_keys_with_expiration only"
  }
}

run "api_key_secret_id_and_audit" {
  command = plan

  variables {
    require_api_key_secret_id = false
    applications              = { terraform = { name = "terraform" } }
    api_keys = {
      stored = {
        application_key = "terraform"
        secret_id       = "55555555-5555-4555-8555-555555555555"
      }
      in_state = { application_key = "terraform" }
    }
  }

  assert {
    condition     = scaleway_iam_api_key.this["stored"].secret_id == "55555555-5555-4555-8555-555555555555"
    error_message = "secret_id must be passed to the API key"
  }

  assert {
    condition     = output.security_audit.api_keys_secret_in_state == ["in_state"]
    error_message = "api_keys_secret_in_state must list only the keys without secret_id"
  }

  assert {
    condition     = toset(keys(output.api_key_secret_keys)) == toset(["in_state"])
    error_message = "api_key_secret_keys must hold only the keys without secret_id"
  }

  assert {
    condition     = alltrue([for k, v in output.api_keys : !contains(keys(v), "secret_key")]) && contains(keys(output.api_keys["stored"]), "access_key")
    error_message = "api_keys must expose the access key and never the secret key"
  }
}

run "api_key_secret_id_regional" {
  command = plan

  variables {
    applications = { terraform = { name = "terraform" } }
    api_keys = {
      stored = {
        application_key = "terraform"
        secret_id       = "fr-par/55555555-5555-4555-8555-555555555555"
      }
    }
  }

  assert {
    condition     = scaleway_iam_api_key.this["stored"].secret_id == "fr-par/55555555-5555-4555-8555-555555555555"
    error_message = "A regional secret_id must be accepted and passed unchanged"
  }
}

run "api_key_secret_id_invalid" {
  command = plan

  variables {
    applications = { terraform = { name = "terraform" } }
    api_keys = {
      stored = { application_key = "terraform", secret_id = "my-secret" }
    }
  }

  expect_failures = [var.api_keys]
}

run "require_api_key_secret_id_default_rejects_key_without_secret_id" {
  command = plan

  variables {
    applications = { terraform = { name = "terraform" } }
    api_keys = {
      k = { application_key = "terraform" }
    }
  }

  expect_failures = [scaleway_iam_api_key.this["k"]]
}

run "require_api_key_secret_id_opt_out_accepts_key_without_secret_id" {
  command = plan

  variables {
    require_api_key_secret_id = false
    applications              = { terraform = { name = "terraform" } }
    api_keys = {
      k = { application_key = "terraform" }
    }
  }

  assert {
    condition     = output.security_audit.api_keys_secret_in_state == ["k"]
    error_message = "A key without secret_id must be accepted and listed in api_keys_secret_in_state"
  }
}

run "require_api_key_secret_id_accepts_all_keys_with_secret_id" {
  command = plan

  variables {
    applications = { terraform = { name = "terraform" } }
    api_keys = {
      stored = {
        application_key = "terraform"
        secret_id       = "55555555-5555-4555-8555-555555555555"
      }
    }
  }

  assert {
    condition     = length(output.security_audit.api_keys_secret_in_state) == 0 && length(output.api_key_secret_keys) == 0
    error_message = "No key may be reported in state when every key sets secret_id"
  }
}

# ------------------------------------------------------------------------------
# Groups
# ------------------------------------------------------------------------------

run "group_declares_external_membership" {
  command = plan

  variables {
    groups = { devs = { name = "devs" } }
  }

  assert {
    condition     = scaleway_iam_group.this["devs"].external_membership == true
    error_message = "Every group must declare external membership to the provider"
  }

  assert {
    condition     = length(scaleway_iam_group_membership.applications) == 0 && length(scaleway_iam_group_membership.users) == 0 && length(output.group_memberships.users) == 0
    error_message = "A group with empty lists must create no membership"
  }
}

run "group_membership_keys" {
  command = plan

  variables {
    applications = { cicd = { name = "cicd" } }
    users        = { bob = { email = "bob@example.com", username = "bob" } }
    groups = {
      devs = {
        name             = "devs"
        application_keys = ["cicd"]
        user_keys        = ["bob"]
        user_ids         = ["12345678-1234-4234-8234-123456789012"]
      }
    }
  }

  assert {
    condition     = toset(keys(scaleway_iam_group_membership.applications)) == toset(["devs-app-cicd"])
    error_message = "Application membership key must be <group>-app-<application key>"
  }

  assert {
    condition     = toset(keys(scaleway_iam_group_membership.users)) == toset(["devs-user-12345678", "devs-user-key-bob"])
    error_message = "User membership keys must be <group>-user-<8 chars> and <group>-user-key-<user key>"
  }

  assert {
    condition     = scaleway_iam_group_membership.users["devs-user-key-bob"].user_id == "66666666-6666-4666-8666-666666666666" && scaleway_iam_group_membership.users["devs-user-12345678"].user_id == "12345678-1234-4234-8234-123456789012"
    error_message = "user_keys must resolve to the module user ID and user_ids be passed unchanged"
  }
}

run "group_unknown_application" {
  command = plan

  variables {
    groups = { devs = { name = "devs", application_keys = ["missing"] } }
  }

  expect_failures = [var.groups]
}

run "group_unknown_user_key" {
  command = plan

  variables {
    groups = { devs = { name = "devs", user_keys = ["missing"] } }
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

# ------------------------------------------------------------------------------
# Policies
# ------------------------------------------------------------------------------

run "policy_several_principals" {
  command = plan

  variables {
    groups = { admins = { name = "admins" } }
    policies = {
      p = {
        name      = "p"
        group_key = "admins"
        user_id   = "12345678-1234-4234-8234-123456789012"
        rules     = [{ permission_set_names = ["IAMReadOnly"] }]
      }
    }
  }

  expect_failures = [var.policies]
}

run "policy_no_principal_set" {
  command = plan

  variables {
    policies = {
      p = { name = "p", rules = [{ permission_set_names = ["IAMReadOnly"] }] }
    }
  }

  expect_failures = [var.policies]
}

run "policy_template_with_principal" {
  command = plan

  variables {
    groups = { admins = { name = "admins" } }
    policies = {
      p = { name = "p", no_principal = true, group_key = "admins", rules = [{ permission_set_names = ["IAMReadOnly"] }] }
    }
  }

  expect_failures = [var.policies]
}

run "policy_invalid_user_id" {
  command = plan

  variables {
    policies = {
      p = { name = "p", user_id = "bob", rules = [{ permission_set_names = ["IAMReadOnly"] }] }
    }
  }

  expect_failures = [var.policies]
}

run "policy_unknown_group" {
  command = plan

  variables {
    policies = {
      p = { name = "p", group_key = "missing", rules = [{ permission_set_names = ["IAMReadOnly"] }] }
    }
  }

  expect_failures = [var.policies]
}

run "policy_unknown_application" {
  command = plan

  variables {
    policies = {
      p = { name = "p", application_key = "missing", rules = [{ permission_set_names = ["IAMReadOnly"] }] }
    }
  }

  expect_failures = [var.policies]
}

run "policy_rule_both_scopes" {
  command = plan

  variables {
    policies = {
      p = {
        name         = "p"
        no_principal = true
        rules = [{
          permission_set_names = ["IAMReadOnly"]
          organization_wide    = true
          project_ids          = ["22222222-2222-4222-8222-222222222222"]
        }]
      }
    }
  }

  expect_failures = [var.policies]
}

run "policy_principals_accepted" {
  command = plan

  variables {
    applications = { terraform = { name = "terraform" } }
    policies = {
      template = { name = "template", no_principal = true, rules = [{ permission_set_names = ["IAMReadOnly"] }] }
      app      = { name = "app", application_key = "terraform", rules = [{ permission_set_names = ["IAMReadOnly"] }] }
      user     = { name = "user", user_id = "12345678-1234-4234-8234-123456789012", rules = [{ permission_set_names = ["IAMReadOnly"] }] }
    }
  }

  assert {
    condition     = scaleway_iam_policy.this["template"].no_principal == true && scaleway_iam_policy.this["template"].user_id == null && scaleway_iam_policy.this["template"].group_id == null && scaleway_iam_policy.this["template"].application_id == null
    error_message = "A template must set no_principal and no other principal"
  }

  assert {
    condition     = scaleway_iam_policy.this["app"].application_id == "33333333-3333-4333-8333-333333333333" && scaleway_iam_policy.this["user"].user_id == "12345678-1234-4234-8234-123456789012"
    error_message = "application_key and user_id must reach the policy"
  }
}

run "policy_rule_scope_and_condition_passed_through" {
  command = plan

  variables {
    policies = {
      dev = {
        name         = "dev"
        no_principal = true
        rules = [
          {
            permission_set_names = ["IAMReadOnly", "BillingReadOnly"]
            organization_wide    = true
            condition            = "request.ip in ['203.0.113.0/24']"
          },
          { permission_set_names = ["InstancesFullAccess"], project_ids = ["22222222-2222-4222-8222-222222222222"] },
        ]
      }
    }
  }

  assert {
    condition     = length(scaleway_iam_policy.this["dev"].rule) == 2
    error_message = "Each rule must be passed to the policy unchanged"
  }

  assert {
    condition     = contains([for r in scaleway_iam_policy.this["dev"].rule : r.organization_id], "11111111-1111-4111-8111-111111111111")
    error_message = "organization_wide must give the rule the organization_id"
  }

  assert {
    condition     = contains([for r in scaleway_iam_policy.this["dev"].rule : r.condition], "request.ip in ['203.0.113.0/24']")
    error_message = "condition must be passed to the rule unchanged"
  }

  assert {
    condition     = anytrue([for r in scaleway_iam_policy.this["dev"].rule : contains(tolist(r.project_ids), "22222222-2222-4222-8222-222222222222")])
    error_message = "project_ids must be passed to the rule"
  }
}

# ------------------------------------------------------------------------------
# Users and SSH keys
# ------------------------------------------------------------------------------

run "users_output_mfa_and_audit" {
  command = plan

  variables {
    users = {
      alice = { email = "alice@example.com", username = "alice" }
    }
  }

  assert {
    condition     = output.users["alice"].mfa == false && output.users["alice"].locked == false
    error_message = "The users output must expose mfa and locked"
  }

  assert {
    condition     = output.security_audit.users_without_mfa == ["alice"] && !contains(keys(output.users["alice"]), "email")
    error_message = "users_without_mfa must list the users without MFA and users must not expose the email"
  }

  assert {
    condition     = toset(keys(output.user_ids)) == toset(["alice"]) && toset(keys(output.user_details)) == toset(["alice"])
    error_message = "user_ids and user_details must be keyed by the users input"
  }
}

run "users_with_mfa_not_in_audit" {
  command = plan

  variables {
    users = {
      bob = { email = "bob@example.com", username = "bob" }
    }
  }

  override_resource {
    target = scaleway_iam_user.this
    values = {
      mfa = true
    }
  }

  assert {
    condition     = length(output.security_audit.users_without_mfa) == 0
    error_message = "A user with MFA must not be listed in users_without_mfa"
  }
}

run "ssh_key_ecdsa_accepted" {
  command = plan

  variables {
    ssh_keys = {
      p256 = { name = "p256", public_key = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTY=" }
      p384 = { name = "p384", public_key = "ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQ=" }
      p521 = { name = "p521", public_key = "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjE=" }
    }
  }

  assert {
    condition     = length(scaleway_iam_ssh_key.this) == 3 && length(output.security_audit.active_ssh_keys) == 3
    error_message = "ECDSA keys of the three NIST curves must be accepted"
  }
}

run "ssh_key_ssh_ecdsa_rejected" {
  command = plan

  variables {
    ssh_keys = {
      bad = { name = "bad", public_key = "ssh-ecdsa AAAA" }
    }
  }

  expect_failures = [var.ssh_keys]
}

run "ssh_key_invalid_public_key" {
  command = plan

  variables {
    ssh_keys = {
      bad = { name = "bad", public_key = "not-a-key" }
    }
  }

  expect_failures = [var.ssh_keys]
}
