# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                     COMPLETE EXAMPLE - OUTPUTS                                ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

output "applications" {
  description = "All created IAM applications"
  value       = module.iam.applications
}

output "application_ids" {
  description = "Application IDs for reference"
  value       = module.iam.application_ids
}

output "api_keys" {
  description = "API keys: ID, access key and dates (no secret key)"
  value       = module.iam.api_keys
}

output "api_key_secret_keys" {
  description = "Secret keys of the API keys without secret_id (sensitive)"
  value       = module.iam.api_key_secret_keys
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

output "group_memberships" {
  description = "Group membership assignments"
  value       = module.iam.group_memberships
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
  description = "All created IAM users (non-sensitive), with MFA and lock state"
  value       = module.iam.users
}

output "user_ids" {
  description = "User IDs for reference"
  value       = module.iam.user_ids
}

output "user_details" {
  description = "Full user details including PII (sensitive)"
  value       = module.iam.user_details
  sensitive   = true
}

output "ssh_keys" {
  description = "All created SSH keys, with their fingerprint"
  value       = module.iam.ssh_keys
}

output "security_audit" {
  description = "Security audit information"
  value       = module.iam.security_audit
}
