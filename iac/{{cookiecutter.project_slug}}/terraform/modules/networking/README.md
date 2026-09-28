# Networking Module

Creates core networking infrastructure: VPC, subnets, and network connectivity.

## Overview

This module provisions a network with:
- One VPC with a specified CIDR block
- Public subnets (routable from the internet)
- Private subnets (internal only, requires NAT for outbound access)

The module is designed to be reused across environments by parameterizing subnet counts and CIDR blocks.

## Inputs

| Name | Type | Description | Default |
|------|------|-------------|---------|
| `environment` | string | Environment name (dev, staging, production) | *required* |
{%- if cookiecutter.cloud_provider == "aws" %}
| `vpc_cidr_block` | string | CIDR block for the VPC | *required* |
| `public_subnets` | map(string) | Map of public subnet names to CIDR blocks | `{"a": "10.0.1.0/24", "b": "10.0.2.0/24"}` |
| `private_subnets` | map(string) | Map of private subnet names to CIDR blocks | `{"a": "10.0.10.0/24", "b": "10.0.11.0/24"}` |
{%- elif cookiecutter.cloud_provider == "azure" %}
| `location` | string | Azure location for resources | `"eastus"` |
| `vnet_address_space` | string | Address space for the virtual network | `"10.0.0.0/16"` |
| `public_subnets` | map(string) | Map of public subnet names to address prefixes | `{"web": "10.0.1.0/24"}` |
| `private_subnets` | map(string) | Map of private subnet names to address prefixes | `{"app": "10.0.10.0/24", "data": "10.0.20.0/24"}` |
{%- elif cookiecutter.cloud_provider == "gcp" %}
| `gcp_region` | string | GCP region for resources | `"us-central1"` |
| `public_subnets` | map(string) | Map of public subnet names to IP CIDR ranges | `{"public": "10.0.1.0/24"}` |
| `private_subnets` | map(string) | Map of private subnet names to IP CIDR ranges | `{"private": "10.0.10.0/24"}` |
{%- endif %}

## Outputs

| Name | Type | Description |
|------|------|-------------|
{%- if cookiecutter.cloud_provider == "aws" %}
| `vpc_id` | string | ID of the VPC |
| `vpc_cidr_block` | string | CIDR block of the VPC |
| `public_subnet_ids` | list(string) | IDs of public subnets |
| `private_subnet_ids` | list(string) | IDs of private subnets |
{%- elif cookiecutter.cloud_provider == "azure" %}
| `resource_group_id` | string | ID of the resource group |
| `vnet_id` | string | ID of the virtual network |
| `public_subnet_ids` | list(string) | IDs of public subnets |
| `private_subnet_ids` | list(string) | IDs of private subnets |
{%- elif cookiecutter.cloud_provider == "gcp" %}
| `network_id` | string | ID of the VPC network |
| `network_name` | string | Name of the VPC network |
| `public_subnet_ids` | list(string) | IDs of public subnets |
| `private_subnet_ids` | list(string) | IDs of private subnets |
{%- endif %}

## Usage

```hcl
module "networking" {
  source = "./modules/networking"
  
  environment = var.environment
{%- if cookiecutter.cloud_provider == "aws" %}
  vpc_cidr_block = "10.0.0.0/16"
  public_subnets = {
    "a" = "10.0.1.0/24"
    "b" = "10.0.2.0/24"
  }
  private_subnets = {
    "a" = "10.0.10.0/24"
    "b" = "10.0.11.0/24"
  }
{%- elif cookiecutter.cloud_provider == "azure" %}
  location      = "eastus"
  vnet_address_space = "10.0.0.0/16"
{%- elif cookiecutter.cloud_provider == "gcp" %}
  gcp_region = "us-central1"
{%- endif %}
}

# Reference outputs in other modules
module "compute" {
  source = "./modules/compute"
  
  subnet_ids = module.networking.private_subnet_ids
  # ...
}
```

## Notes

- Subnets are created in multiple availability zones for high availability
- Public subnets have `map_public_ip_on_launch` enabled for EC2 instances
- Private subnets are internal-only and require a NAT gateway for outbound internet access
- All resources are tagged with the environment name for identification and cost allocation
