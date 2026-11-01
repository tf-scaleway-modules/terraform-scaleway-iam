# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                     MINIMAL EXAMPLE - OUTPUTS                                 ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

output "application_id" {
  description = "The Terraform application ID"
  value       = module.iam.application_ids["terraform"]
}

output "api_key_access_key" {
  description = "The API key access key (public part)"
  value       = module.iam.api_keys["terraform_key"].access_key
}
