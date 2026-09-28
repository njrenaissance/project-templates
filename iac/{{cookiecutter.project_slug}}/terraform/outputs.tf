# Outputs are the values that Terraform exports from this configuration.
# Use outputs to:
# - Display resource IDs after apply
# - Export values for consumption by other modules or projects
# - Make cross-stack references easier to maintain

# Example outputs - add your infrastructure outputs here:
# output "vpc_id" {
#   description = "ID of the created VPC"
#   value       = module.networking.vpc_id
# }

output "deployed_at" {
  description = "Timestamp when this configuration was last applied"
  value       = timestamp()
}
