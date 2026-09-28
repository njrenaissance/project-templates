{%- if cookiecutter.cloud_provider == "aws" %}
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  }
}
{%- elif cookiecutter.cloud_provider == "azure" %}
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}
{%- elif cookiecutter.cloud_provider == "gcp" %}
provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}
{%- endif %}
