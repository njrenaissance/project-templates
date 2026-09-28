# Terraform Language Rules

Applied automatically when editing `.tf` files.

## Code Style

- Use `terraform fmt` to format all files
- Indentation: 2 spaces
- Line length: keep logical blocks readable (no strict limit, but aim for clarity)
- Use descriptive resource names: `aws_vpc` → `aws_vpc.main`, `aws_instance` → `aws_instance.app_server`

## Variable Declarations

Every variable must have a description:

```hcl
variable "instance_type" {
  type        = string
  description = "EC2 instance type (e.g., t3.medium)"
  default     = "t3.micro"
}
```

Use validation rules for constrained values:

```hcl
variable "environment" {
  type        = string
  description = "Environment name (dev, staging, production)"
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Must be dev, staging, or production."
  }
}
```

## Resource Declarations

Order resources logically:
1. Data sources (read-only lookups)
2. Primary resources
3. Dependent resources
4. IAM policies and tags

Use descriptive names with environment context:

```hcl
resource "aws_instance" "app_server" {
  # instance for the app tier, not generic "server"
}

resource "aws_security_group" "database" {
  # security group for database, not generic "sg"
}
```

Use `for_each` or `count` for multiple instances instead of copy-paste:

```hcl
# Bad: three identical resources
resource "aws_instance" "app_1" { ... }
resource "aws_instance" "app_2" { ... }
resource "aws_instance" "app_3" { ... }

# Good: parameterized
resource "aws_instance" "app" {
  for_each = var.app_instances
  # ...
}
```

## Comments

Add comments only when the *why* is non-obvious:

```hcl
# Use gp3 for better price/performance compared to gp2
resource "aws_ebs_volume" "data" {
  type = "gp3"
}

# Enable public access only in dev; production uses VPN
publicly_accessible = var.environment == "dev"
```

Avoid comments that repeat what the code says:

```hcl
# Bad: obvious from code
instance_type = "t3.medium"  # Set instance type to t3.medium

# Good: explains the why
instance_type = "t3.medium"  # Balances cost and performance for dev workloads
```

## Locals

Use `locals` to reduce repetition and improve readability:

```hcl
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
  
  app_name = "${var.environment}-${var.project_name}"
}

resource "aws_instance" "app" {
  tags = merge(local.common_tags, {
    Name = local.app_name
  })
}
```

## Module Usage

Pass variables explicitly; avoid relying on implicit inheritance:

```hcl
# Bad: relies on local variables being in scope
module "networking" {
  source = "./modules/networking"
  # Silently uses var.environment, var.project_name
}

# Good: explicit dependencies
module "networking" {
  source = "./modules/networking"
  
  environment  = var.environment
  project_name = var.project_name
  cidr_block   = var.vpc_cidr_block
}
```

Reference module outputs explicitly:

```hcl
module "compute" {
  source = "./modules/compute"
  
  subnet_ids = module.networking.private_subnet_ids
  # explicit reference to networking outputs
}
```

## Conditional Logic

Use `count` or `for_each` to conditionally create resources:

```hcl
# Create a resource only in production
resource "aws_backup_vault" "main" {
  count = var.environment == "production" ? 1 : 0
}

# Create multiple resources from a map
resource "aws_subnet" "main" {
  for_each = var.subnets
  
  cidr_block = each.value.cidr_block
  # ...
}
```

Avoid overly complex conditionals in variable expressions — keep it simple.

## Output Exports

Export values needed by other configurations:

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "db_endpoint" {
  description = "RDS endpoint for application connection"
  value       = aws_db_instance.main.endpoint
  sensitive   = true  # Don't log passwords or connection strings
}
```

Never export secrets without marking them `sensitive = true`.
