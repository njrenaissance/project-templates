# Security Best Practices

Security scanning is enabled for this project to catch common misconfigurations before they reach production.

## Secrets Management

**Never** commit secrets to git:

- Database passwords
- API keys
- AWS access keys
- Private certificates
- OAuth tokens

Use external secret stores:

{%- if cookiecutter.cloud_provider == "aws" %}
- **AWS Secrets Manager**: Store and rotate secrets
- **AWS Parameter Store**: Store configuration and secrets
- **Environment variables**: Load secrets at runtime
{%- elif cookiecutter.cloud_provider == "azure" %}
- **Azure Key Vault**: Store and manage secrets
- **Environment variables**: Load secrets at runtime
{%- elif cookiecutter.cloud_provider == "gcp" %}
- **Google Secret Manager**: Store and rotate secrets
- **Environment variables**: Load secrets at runtime
{%- endif %}

In Terraform, reference secrets without committing them:

```hcl
variable "db_password" {
  type        = string
  description = "Database password (from secret store)"
  sensitive   = true
}

output "connection_string" {
  value       = "postgres://user:${var.db_password}@${aws_db_instance.main.endpoint}"
  sensitive   = true  # Don't log this
}
```

## State File Security

Terraform state contains sensitive values (passwords, keys) — protect it:

- **Enable encryption** on remote state backend
- **Enable versioning** for recovery
- **Enable state locking** to prevent concurrent modifications
- **Restrict access** via IAM policies or RBAC
- **Never commit** local `.tfstate` files

{%- if cookiecutter.cloud_provider == "aws" %}
For AWS S3 backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true              # Enable server-side encryption
    dynamodb_table = "terraform-locks" # Enable state locking
  }
}
```

Add S3 bucket policy to restrict access:

```hcl
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```
{%- elif cookiecutter.cloud_provider == "azure" %}
For Azure Storage backend:

```hcl
terraform {
  backend "azurerm" {
    storage_account_name = "tfstate"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
    # Enable encryption and access control in Azure portal
  }
}
```

Restrict blob access via Azure RBAC.
{%- elif cookiecutter.cloud_provider == "gcp" %}
For GCS backend:

```hcl
terraform {
  backend "gcs" {
    bucket  = "terraform-state"
    prefix  = "prod"
    # Enable encryption via Google-managed keys
  }
}
```

Restrict bucket access via IAM policies.
{%- endif %}

## Infrastructure Security

Follow cloud provider security best practices:

{%- if cookiecutter.cloud_provider == "aws" %}
- **VPCs**: Use private subnets for non-public resources
- **Security Groups**: Apply least-privilege ingress rules
- **IAM**: Use roles instead of access keys; grant only needed permissions
- **Encryption**: Enable EBS encryption by default
- **Logging**: Enable VPC Flow Logs, S3 access logging, CloudTrail
- **Compliance**: Use Config rules to enforce compliance
{%- elif cookiecutter.cloud_provider == "azure" %}
- **VNets**: Segment networks by tier (web, app, data)
- **NSGs**: Apply least-privilege network rules
- **IAM**: Use managed identities where possible
- **Encryption**: Enable encryption at rest and in transit
- **Logging**: Enable diagnostic settings for all resources
- **Policy**: Use Azure Policy to enforce compliance
{%- elif cookiecutter.cloud_provider == "gcp" %}
- **VPCs**: Use firewall rules for network segmentation
- **IAM**: Use service accounts with minimal roles
- **Encryption**: Use customer-managed keys (CMEK) where sensitive
- **Logging**: Enable Cloud Logging and Cloud Audit Logs
- **Security Command Center**: Monitor for security findings
{%- endif %}

## Code Review

Security improvements must be reviewed before merge:

- Check for hardcoded secrets
- Verify least-privilege IAM policies
- Ensure encryption is enabled
- Validate network segmentation
- Check for open public access

## Security Scanning

Run security checks before commit:

```bash
# Scan for misconfigurations (requires tfsec)
tfsec terraform/

# Validate compliance (requires terrascan)
terrascan scan -d terraform/
```

These scans are enforced in CI/CD.
