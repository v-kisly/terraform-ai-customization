# Terraform AI Customization

This repository provides a Terraform-oriented AI workflow for infrastructure provisioning.
It includes a Terraform agent for requirement gathering and orchestration, shared Terraform standards for repository-wide conventions, and a Terraform checker skill for validation.

## Key files

| File | Purpose |
|------|---------|
| `.claude/rules/terraform.md` | Path-scoped Terraform rules for Claude Code (`.tf` files) |
| `.claude/agents/terraform.md` | Terraform agent in Claude format |
| `.claude/skills/terraform-checker/SKILL.md` | Validation skill definition |
| `.claude/skills/terraform-checker/terraform-checker.sh` | Linux/macOS checker script |
| `.claude/skills/terraform-checker/terraform-checker.yaml` | Checker configuration |

## Workflow

1. Select or invoke the Terraform agent when provisioning or changing infrastructure.
2. Let the agent gather missing inputs (region, CIDRs, backend, naming) before writing code.
3. The agent follows `.claude/rules/terraform.md` for repository standards.
4. The agent generates Terraform files (`main.tf`, `variables.tf`, `outputs.tf`, etc.) according to the gathered requirements and repository standards.
5. After code changes, the agent runs the `terraform-checker` skill for validation.
6. The skill reports findings by severity with file and line references.
7. As an optional final step, and only on user request, the agent generates a `terraform plan` and records any planning issues for remediation.
8. For long `terraform plan` runs, the agent must wait for completion in the same terminal session and must not restart `terraform plan` until the prior run has explicitly finished.

## Standards

Terraform conventions are defined in `.claude/rules/terraform.md`.
All agents and rules reference this file as the single policy source.
Do not duplicate these standards in agent or rule files.
