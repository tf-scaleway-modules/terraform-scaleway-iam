# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                     MINIMAL EXAMPLE - OUTPUTS                                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

output "application_id" {
  description = "The Terraform application ID"
  value       = module.iam.application_ids["terraform"]
}

output "api_key_access_key" {
  description = "The API key access key (public part)"
  value       = module.iam.api_key_access_keys["terraform_key"]
}

output "api_key_secret" {
  description = "The API key secret (sensitive)"
  value       = module.iam.api_keys["terraform_key"].secret_key
  sensitive   = true
}

output "summary" {
  description = "Summary of created resources"
  value       = module.iam.summary
}
