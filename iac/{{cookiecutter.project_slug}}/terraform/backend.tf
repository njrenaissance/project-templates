{%- if cookiecutter.enable_remote_state == "yes" %}
# Configure remote state backend
# Uncomment the appropriate backend configuration for your setup:

# AWS S3 Backend (recommended for AWS projects)
{%- if cookiecutter.cloud_provider == "aws" %}
terraform {
  backend "s3" {
    # bucket         = "your-terraform-state-bucket"
    # key            = "{{ cookiecutter.project_slug }}/terraform.tfstate"
    # region         = "us-east-1"
    # encrypt        = true
    # dynamodb_table = "terraform-locks"
  }
}
{%- elif cookiecutter.cloud_provider == "azure" %}
# Azure Storage Backend
terraform {
  backend "azurerm" {
    # resource_group_name  = "your-resource-group"
    # storage_account_name = "your-storage-account"
    # container_name       = "tfstate"
    # key                  = "{{ cookiecutter.project_slug }}/terraform.tfstate"
  }
}
{%- elif cookiecutter.cloud_provider == "gcp" %}
# Google Cloud Storage Backend
terraform {
  backend "gcs" {
    # bucket = "your-terraform-state-bucket"
    # prefix = "{{ cookiecutter.project_slug }}"
  }
}
{%- endif %}
{%- else %}
# Remote state backend not enabled.
# To use remote state, configure your backend provider above and run:
#   terraform init
{%- endif %}
