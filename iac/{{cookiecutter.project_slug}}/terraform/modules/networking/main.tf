# Networking module — VPC, subnets, and network connectivity
#
# This is a template module. Replace with your actual networking resources.

{%- if cookiecutter.cloud_provider == "aws" %}
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment}-vpc"
  }
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = data.aws_availability_zones.available.names[index(keys(var.public_subnets), each.key)]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[index(keys(var.private_subnets), each.key)]

  tags = {
    Name = "${var.environment}-private-${each.key}"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
{%- elif cookiecutter.cloud_provider == "azure" %}
resource "azurerm_resource_group" "main" {
  name     = "${var.environment}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.environment}-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.vnet_address_space]
}

resource "azurerm_subnet" "public" {
  for_each = var.public_subnets

  name                 = "${var.environment}-public-${each.key}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value]
}

resource "azurerm_subnet" "private" {
  for_each = var.private_subnets

  name                 = "${var.environment}-private-${each.key}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value]
}
{%- elif cookiecutter.cloud_provider == "gcp" %}
resource "google_compute_network" "main" {
  name                    = "${var.environment}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  for_each = var.public_subnets

  name          = "${var.environment}-public-${each.key}"
  ip_cidr_range = each.value
  region        = var.gcp_region
  network       = google_compute_network.main.id
}

resource "google_compute_subnetwork" "private" {
  for_each = var.private_subnets

  name          = "${var.environment}-private-${each.key}"
  ip_cidr_range = each.value
  region        = var.gcp_region
  network       = google_compute_network.main.id
}
{%- endif %}
