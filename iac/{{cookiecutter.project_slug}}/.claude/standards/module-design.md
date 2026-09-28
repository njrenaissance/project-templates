# Module Design

Modules are the primary unit of reusability in this codebase. This document explains how to design, structure, and use modules effectively.

## What Goes In a Module

A module should encapsulate one **concern** — a logical unit of infrastructure that can be understood and tested in isolation.

**Good module boundaries:**
- `networking/` — VPCs, subnets, route tables, gateways
- `compute/` — EC2, load balancers, auto-scaling groups
- `databases/` — RDS, DynamoDB, or other data stores
- `security/` — IAM roles, policies, security groups

**Poor module boundaries:**
- Mixing networking + compute (separate concerns)
- Single-resource modules (no reusability benefit)
- Overly generic modules that try to handle all cases

A module should answer the question: "What infrastructure concern does this solve?"

## Module Structure

```
modules/networking/
├── main.tf              # Resource definitions
├── variables.tf         # Input variables (with descriptions & validation)
├── outputs.tf           # Exported values
├── README.md            # Usage documentation
└── examples/            # (Optional) Example instantiations
    └── basic/
        └── main.tf
```

### variables.tf

Every variable must have:
- **type**: Explicit type annotation
- **description**: What it does, format expectations
- **validation**: Constraints on allowed values (where applicable)

```hcl
variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for the VPC (e.g., 10.0.0.0/16)"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "Must be a valid CIDR block."
  }
}
```

### main.tf

Define resources in a logical order:
1. Data sources (look up existing resources)
2. Primary resources (VPC, RDS, etc.)
3. Dependent resources (subnets, security groups)
4. Metadata (tags, IAM policies)

```hcl
# Data source: look up an AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Primary resource
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  
  tags = {
    Name = "${var.environment}-web"
  }
}
```

### outputs.tf

Export values that consumers need:
- Resource IDs
- Endpoints (DNS names, IP addresses)
- Connection strings
- Metadata for chaining modules

```hcl
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = aws_instance.web.public_ip
}
```

### README.md

Every module must include a README documenting:
- **Purpose**: What does this module create?
- **Inputs**: List of variables with descriptions
- **Outputs**: List of exported values
- **Usage**: Example code showing how to use the module
- **Notes**: Assumptions, gotchas, or special cases

```markdown
# networking

Creates a VPC with public and private subnets across multiple availability zones.

## Inputs

- `vpc_cidr_block` (string, required): CIDR block for the VPC
- `availability_zones` (list(string), required): AZs to deploy subnets in
- `public_subnet_cidrs` (map(string), required): Map of subnet name to CIDR block

## Outputs

- `vpc_id`: ID of the created VPC
- `public_subnet_ids`: List of public subnet IDs
- `private_subnet_ids`: List of private subnet IDs

## Usage

\`\`\`hcl
module "networking" {
  source = "./modules/networking"
  
  vpc_cidr_block = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  ...
}
\`\`\`
```

## Module Composition

Modules can use other modules (composition), but keep nesting shallow. Two levels is typical; three or more suggests the modules need redesign.

```hcl
# root main.tf
module "networking" {
  source = "./modules/networking"
  # ...
}

module "compute" {
  source = "./modules/compute"
  
  subnet_ids = module.networking.private_subnet_ids
  # ... compose modules
}
```

## Reusability

Modules must be parameterized to be reusable across environments and use cases:

- **Never hardcode values**: Use variables instead
- **Parameterize counts**: Use `count` or `for_each` to scale resources
- **Accept tags**: Let the caller supply custom tags
- **Use maps for multi-item lists**: Instead of `instance_1_type`, `instance_2_type`, use a map

```hcl
# Bad: hardcoded, not reusable
resource "aws_instance" "app" {
  count         = 3
  instance_type = "t3.medium"
  # ...
}

# Good: parameterized
resource "aws_instance" "app" {
  for_each      = var.app_instances
  instance_type = each.value.instance_type
  # ...
}
```

## Testing Modules

Each module should be independently testable. To test a module:

1. Create an example in `modules/{name}/examples/basic/`
2. Run `terraform init && terraform plan` to verify it works
3. Run `terraform apply` and `terraform destroy` to verify lifecycle

Modules are integration-tested in CI/CD via Terratest or similar (if testing is enabled).
