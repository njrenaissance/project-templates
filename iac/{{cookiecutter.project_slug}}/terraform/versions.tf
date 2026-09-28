terraform {
  required_version = "{{ cookiecutter.terraform_version }}"

  required_providers {
{%- if cookiecutter.cloud_provider == "aws" %}
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
{%- elif cookiecutter.cloud_provider == "azure" %}
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
{%- elif cookiecutter.cloud_provider == "gcp" %}
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
{%- endif %}
  }
}
