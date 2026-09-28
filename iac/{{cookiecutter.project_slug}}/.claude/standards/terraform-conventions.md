# Terraform Conventions

All Terraform code must follow HashiCorp's best practices and the conventions outlined here.

## File Organization

- **versions.tf**: Terraform version constraints and required providers
- **providers.tf**: Provider configuration and authentication
- **backend.tf**: Remote state configuration
- **main.tf**: Primary resource definitions and module orchestration
- **variables.tf**: Input variable declarations with descriptions and validation
- **outputs.tf**: Exported values for consumption by other modules or projects
- **terraform.tfvars**: Variable values (environment-specific, in .gitignore)
- **modules/**: Reusable infrastructure components, each with its own `variables.tf`, `main.tf`, `outputs.tf`

## Naming Conventions

- **Resources**: Use descriptive names following the pattern `{environment}-{resource_type}-{name}`
  - Example: `dev-vpc-main`, `prod-rds-primary`
- **Modules**: Use plural nouns for clarity
  - Example: `modules/networking/`, `modules/compute/`, `modules/databases/`
- **Variables**: Use snake_case, group related variables together
  - Example: `vpc_cidr_block`, `db_instance_type`
- **Outputs**: Use snake_case and include the resource type
  - Example: `vpc_id`, `rds_endpoint`, `security_group_id`

## Variables and Validation

Every input variable must include:

- **type**: Explicit type annotation (string, number, bool, list, map, object)
- **description**: What this variable is for and expected format
- **validation** (where applicable): Constraints on acceptable values

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, production)"
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}
```

Default values are acceptable for variables that have sensible fallbacks, but required variables must have no default.

## Outputs

Export critical values that other stacks might need:

- Resource IDs (VPC ID, subnet IDs, security group IDs)
- Endpoints (database endpoints, load balancer DNS names)
- Connection strings (where safe to export)
- Metadata (region, account ID, tags applied)

Never export secrets or sensitive values. Use `sensitive = true` for outputs that should not be displayed in plan output.

## Module Usage

Modules are the primary unit of reusability. Organize modules by concern:

```hcl
module "networking" {
  source = "./modules/networking"
  
  project_name = var.project_name
  environment  = var.environment
  cidr_block   = var.vpc_cidr_block
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

module "compute" {
  source = "./modules/compute"
  
  subnet_ids = module.networking.private_subnet_ids
  # ... other variables
}
```

Modules must be:

- **Self-contained**: Include all required resources (don't rely on external state)
- **Parameterized**: Accept variables instead of hardcoding values
- **Documented**: Each module has a README explaining inputs, outputs, and usage
- **Tested**: Each module can be instantiated and destroyed independently

## State Management

- Never commit `.tfstate` or `*.tfstate.*` files — use remote state backend
- Use state locking to prevent concurrent modifications (S3 + DynamoDB for AWS, etc.)
- Separate state by environment (`dev.tfvars`, `staging.tfvars`, `production.tfvars`)
- Use `terraform remote config` or backend blocks to switch between state backends

## Code Quality

Before committing:

```bash
terraform fmt -recursive .     # Format all files
terraform validate             # Check for syntax errors
terraform plan                 # Review changes
```

These checks are enforced in CI/CD and locally via pre-commit hooks (if enabled).

## Comments

Add comments only when the why is non-obvious:

- Explain resource choices (e.g., why a particular instance type)
- Clarify complex expressions or conditionals
- Link to ADRs or external documentation
- Avoid restating what the code obviously does

```hcl
# Use gp3 for better price/performance over gp2
resource "aws_ebs_volume" "data" {
  # ...
  type = "gp3"
}
```

## Secrets and Sensitive Values

Never hardcode secrets in Terraform code:

- Use environment variables: `${var.secret_value}`
- Use external secret managers (AWS Secrets Manager, Azure Key Vault, etc.)
- Mark sensitive variables as such: `sensitive = true`
- Use `.tfvars` (in .gitignore) for local development secrets

```hcl
variable "db_password" {
  type        = string
  description = "Database password (from AWS Secrets Manager)"
  sensitive   = true
}
```
