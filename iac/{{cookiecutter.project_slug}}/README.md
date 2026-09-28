# {{ cookiecutter.project_name }}

Infrastructure as code for {{ cookiecutter.cloud_provider | capitalize }} using Terraform.

## Quick Start

1. **Initialize Terraform**:
   ```bash
   cd terraform
   terraform init
   ```

2. **Configure Variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Plan Changes**:
   ```bash
   terraform plan -out=tfplan
   ```

4. **Apply Configuration**:
   ```bash
   terraform apply tfplan
   ```

## Project Structure

```
├── terraform/
│   ├── versions.tf           # Terraform and provider versions
│   ├── providers.tf          # Provider configuration
│   ├── backend.tf            # Remote state configuration
│   ├── main.tf               # Primary resource definitions
│   ├── variables.tf          # Input variables
│   ├── outputs.tf            # Output values
│   ├── terraform.tfvars      # Variable values (in .gitignore)
│   ├── terraform.tfvars.example  # Template for tfvars
│   └── modules/              # Reusable infrastructure modules
├── .github/
│   └── workflows/            # GitHub Actions for CI/CD
├── CLAUDE.md                 # Claude Code project guidance
└── README.md                 # This file
```

## Documentation

See [CLAUDE.md](CLAUDE.md) for detailed conventions and standards for this project.

## Cloud Provider: {{ cookiecutter.cloud_provider | capitalize }}

This project is configured for **{{ cookiecutter.cloud_provider | upper }}**. Provider-specific documentation:

{%- if cookiecutter.cloud_provider == "aws" %}
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Best Practices](https://docs.aws.amazon.com/whitepapers/latest/terraform-on-aws/welcome.html)
{%- elif cookiecutter.cloud_provider == "azure" %}
- [Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Terraform Quickstart](https://learn.microsoft.com/en-us/azure/developer/terraform/)
{%- elif cookiecutter.cloud_provider == "gcp" %}
- [Google Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP Terraform Guide](https://cloud.google.com/docs/terraform)
{%- endif %}

## License

[Add your license here]
