# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                     COMPLETE EXAMPLE - OUTPUTS                                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

output "summary" {
  description = "Summary of all IAM resources created"
  value       = module.iam.summary
}

output "applications" {
  description = "All created IAM applications"
  value       = module.iam.applications
}

output "application_ids" {
  description = "Application IDs for reference"
  value       = module.iam.application_ids
}

output "api_key_access_keys" {
  description = "API key access keys (public part)"
  value       = module.iam.api_key_access_keys
}

output "api_keys" {
  description = "Full API key information (sensitive)"
  value       = module.iam.api_keys
  sensitive   = true
}

output "groups" {
  description = "All created IAM groups"
  value       = module.iam.groups
}

output "group_ids" {
  description = "Group IDs for reference"
  value       = module.iam.group_ids
}

output "policies" {
  description = "All created IAM policies"
  value       = module.iam.policies
}

output "policy_ids" {
  description = "Policy IDs for reference"
  value       = module.iam.policy_ids
}

output "users" {
  description = "All created IAM users (non-sensitive)"
  value       = module.iam.users
}

output "user_details" {
  description = "Full user details including PII (sensitive)"
  value       = module.iam.user_details
  sensitive   = true
}

output "user_ids" {
  description = "User IDs for reference"
  value       = module.iam.user_ids
}

output "ssh_keys" {
  description = "All created SSH keys"
  value       = module.iam.ssh_keys
}

output "ssh_key_fingerprints" {
  description = "SSH key fingerprints for verification"
  value       = module.iam.ssh_key_fingerprints
}

output "group_memberships" {
  description = "Group membership assignments"
  value       = module.iam.group_memberships
}

output "security_audit" {
  description = "Security audit information"
  value       = module.iam.security_audit
}
