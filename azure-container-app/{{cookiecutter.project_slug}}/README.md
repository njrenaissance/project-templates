# {{ cookiecutter.project_name }}

Generated from the `azure-container-app` cookiecutter template.

## Prerequisites

- Azure CLI logged in
- Container registry: `{{ cookiecutter.container_registry }}`
- Resource group: `{{ cookiecutter.azure_resource_group }}`

## Deploy

Push to `main` — GitHub Actions builds the image and updates the Container App automatically.
