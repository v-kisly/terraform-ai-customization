---
applyTo: "**/*.tf,**/*.tfvars,**/*.tftest.hcl,**/*.tftest.tf"
description: "Shared Terraform conventions for structure, formatting, validation, and security."
---

# Terraform Repository Guidance

Use these conventions for all Terraform work in this repository. Agent files should orchestrate workflow and call skills; they should not duplicate the standards below.

## Required module files

Every module must include:
- `main.tf`
- `variables.tf`
- `outputs.tf`
- `README.md` for root modules and externally reusable nested modules

## Recommended files

Add these when they fit the module:
- `providers.tf` for provider configuration
- `terraform.tf` or `versions.tf` for Terraform and provider version constraints
- `backend.tf` for root module backend configuration
- `locals.tf` for shared expressions
- `tests/*.tftest.tf` for Terraform tests

## Structure and naming

- Keep modules focused on one infrastructure concern.
- Split large roots into logical files such as `network.tf`, `compute.tf`, `storage.tf`, and `security.tf`.
- Use descriptive resource names.
- Keep input variables and outputs in alphabetical order.

## Formatting

- Use 2 spaces per nesting level.
- Separate top-level blocks with one blank line.
- Place meta-arguments before required and optional arguments.
- Keep nested blocks after arguments.

## Versions and dependencies

- Pin provider versions.
- Use realistic and compatible module versions.
- Do not leave provider or module versions unconstrained.

## Backend and state

- Default to local backend unless the user requests another backend.
- Before generating a non-local backend, gather all required backend parameters.
- Ensure `.gitignore` excludes Terraform state files and local Terraform artifacts.

## Security

- Never hardcode secrets or sensitive values.
- Prefer least-privilege IAM and access patterns.
- Include consistent tagging for ownership, environment, and cost allocation when the target platform supports it.

## Validation workflow

- Do not run `terraform apply` as part of generation or review.
- Validate generated code through the `terraform-checker` skill.
- Report findings with severity and file-level remediation guidance.