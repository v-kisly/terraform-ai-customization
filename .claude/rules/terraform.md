---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/*.tftest.hcl"
  - "**/*.tftest.tf"
description: "Shared Terraform conventions for structure, formatting, validation, and security."
---

# Terraform Repository Guidance

Use these conventions for all Terraform work in this repository. Agent files should orchestrate workflow and call skills; they should not duplicate the standards below.

## Code generation approach

- Generate code according to Terraform best practices.
- Apply only the minimal change needed to fulfil the request.
- Do not increase complexity for the sake of "improvement"; keep changes minimal and targeted.

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
- Include consistent tagging when the target platform supports it.
- Define a mandatory common tag set in `locals` using the `common_tags` pattern.
- Required tags:
  - `owner`
  - `environment`
  - `cost_center`
  - `managed_by` (must be set to `terraform`)
- Include an optional `iac_origin` tag sourced from input variable `var.iac_origin`.
- Use `iac_origin` to store where IaC came from (for example: repository URL/name, mono-repo path, or CI/CD pipeline identifier).
- If `var.iac_origin` is not provided (null or empty), exclude `iac_origin` from the final tag map.
- Use this baseline pattern:

  ```hcl
  variable "iac_origin" {
    description = "Optional IaC origin (repo, path, or pipeline id)."
    type        = string
    default     = null
  }

  locals {
    common_tags = merge(
      {
        owner       = var.owner
        environment = var.environment
        cost_center = var.cost_center
        managed_by  = "terraform"
      },
      var.iac_origin != null && trimspace(var.iac_origin) != "" ? {
        iac_origin = var.iac_origin
      } : {}
    )
  }
  ```

## Validation workflow

- Do not run `terraform apply` as part of generation or review.
- Validate generated code through the `terraform-checker` skill.
- Run `terraform plan` only as an optional final step and only when the user requests it.
- Report findings with severity and file-level remediation guidance.
- Fix all `critical` findings before considering the task complete.
- If planning reveals issues, record them and remediate using the same severity policy as validation findings.
- Handle non-critical findings (`high`, `medium`, `low`) based on context, risk, and user priorities; document any intentional deferrals.
