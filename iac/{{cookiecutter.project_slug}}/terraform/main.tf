# Main configuration for {{ cookiecutter.project_name }}
#
# This file orchestrates the creation of cloud infrastructure.
# Modular resources are defined in the ./modules/ directory.

locals {
  project_name = var.project_name
  environment  = var.environment
}

# Example: Add your infrastructure modules here
# module "networking" {
#   source = "./modules/networking"
#
#   project_name = local.project_name
#   environment  = local.environment
#   cidr_block   = var.vpc_cidr_block
# }
