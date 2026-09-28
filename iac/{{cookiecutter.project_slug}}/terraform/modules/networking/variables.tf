variable "environment" {
  type        = string
  description = "Environment name (dev, staging, production)"
}

{%- if cookiecutter.cloud_provider == "aws" %}
variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for the VPC (e.g., 10.0.0.0/16)"

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "public_subnets" {
  type        = map(string)
  description = "Map of public subnet names to CIDR blocks"
  default     = {
    "a" = "10.0.1.0/24"
    "b" = "10.0.2.0/24"
  }
}

variable "private_subnets" {
  type        = map(string)
  description = "Map of private subnet names to CIDR blocks"
  default     = {
    "a" = "10.0.10.0/24"
    "b" = "10.0.11.0/24"
  }
}
{%- elif cookiecutter.cloud_provider == "azure" %}
variable "location" {
  type        = string
  description = "Azure location for resources"
  default     = "eastus"
}

variable "vnet_address_space" {
  type        = string
  description = "Address space for the virtual network (e.g., 10.0.0.0/16)"
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  type        = map(string)
  description = "Map of public subnet names to address prefixes"
  default     = {
    "web" = "10.0.1.0/24"
  }
}

variable "private_subnets" {
  type        = map(string)
  description = "Map of private subnet names to address prefixes"
  default     = {
    "app"  = "10.0.10.0/24"
    "data" = "10.0.20.0/24"
  }
}
{%- elif cookiecutter.cloud_provider == "gcp" %}
variable "gcp_region" {
  type        = string
  description = "GCP region for resources"
  default     = "us-central1"
}

variable "public_subnets" {
  type        = map(string)
  description = "Map of public subnet names to IP CIDR ranges"
  default     = {
    "public" = "10.0.1.0/24"
  }
}

variable "private_subnets" {
  type        = map(string)
  description = "Map of private subnet names to IP CIDR ranges"
  default     = {
    "private" = "10.0.10.0/24"
  }
}
{%- endif %}
