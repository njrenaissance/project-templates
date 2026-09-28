# {{ cookiecutter.project_name }}

Infrastructure as code using [Terraform](https://www.terraform.io/) on {{ cookiecutter.cloud_provider | capitalize }}.

## Profile

Features enabled for this project:

- Cloud provider: {{ cookiecutter.cloud_provider }}
- Terraform version: {{ cookiecutter.terraform_version }}
- Remote state backend: {{ "enabled" if cookiecutter.enable_remote_state == "yes" else "disabled" }}
- Integration testing: {{ "enabled" if cookiecutter.testing == "yes" else "disabled" }}
- Security scanning: {{ "enabled" if cookiecutter.security_scanning == "yes" else "disabled" }}
- Diagramming: {{ "enabled" if cookiecutter.diagrams == "yes" else "disabled" }}

## Imports

- @.claude/standards/terraform-conventions.md
- @.claude/standards/module-design.md
{%- if cookiecutter.testing == "yes" %}
- @.claude/standards/testing.md
{%- endif %}
{%- if cookiecutter.security_scanning == "yes" %}
- @.claude/standards/security.md
{%- endif %}
{%- if cookiecutter.diagrams == "yes" %}
- @.claude/standards/diagramming.md
{%- endif %}

## Structure

```text
├── modules/
│   ├── networking/
│   ├── compute/
│   └── storage/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── production/
├── tests/
│   └── terraform_test.py
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml
│       └── terraform-apply.yml
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
└── .terraformrc
```

## Commands

```bash
cd terraform
terraform init                                # initialize terraform
terraform fmt -recursive ..                   # format all terraform files
terraform validate                            # validate configuration
terraform plan -out=tfplan                   # plan infrastructure changes
terraform apply tfplan                        # apply changes
{% if cookiecutter.testing == "yes" %}pytest ../tests/                     # run integration tests
{% endif %}```

## Git Workflow

1. Create a feature branch: `git checkout -b feat/add-rds-instance`
2. Make changes to `.tf` files
3. Run `terraform fmt` and `terraform validate`
4. Commit with clear message: `git commit -m "feat: add RDS instance with encryption"`
5. Push to origin: `git push -u origin feat/add-rds-instance`
6. Open a PR — CI will run `terraform plan` automatically
7. Review the plan output in the PR
8. Merge — CI will run `terraform apply` on main

## Key Conventions

All code must follow Terraform best practices:

- **Single Responsibility**: Each module handles one concern (networking, compute, storage)
- **Reusable Modules**: Modules are parameterized and can be used across environments
- **State Management**: Never commit `.tfstate` files; use remote state backend
- **Variable Validation**: All variables include type, description, and validation rules
- **Output Documentation**: Outputs are well-documented and exported for cross-stack reference
- **Naming**: Resources follow a consistent naming convention: `{environment}-{resource_type}-{name}`

Terraform- and environment-specific conventions live in `.claude/standards/` and load automatically when Claude touches matching files.

Before considering a change done:

```bash
terraform fmt -recursive .
terraform validate
terraform plan
```

## Template Sync

This project is linked to the cookiecutter template it was generated from via `.cruft.json`. To pull template updates, use the **`update-from-template`** skill.
