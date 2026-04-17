# Terraform AI Customization

This repository provides a minimal Terraform-focused AI workflow for infrastructure work.

It includes:
- a Terraform agent for requirement gathering and orchestration;
- shared Terraform standards for repository-wide conventions;
- a Terraform checker skill for validation.

For more details, see the `CLAUDE.md` file and individual files in the `.claude` directory.

## How to Use

1. Copy `CLAUDE.md` and the `.claude` directory into your repository.
2. In your IDE choose the `terraform` agent.
3. Cooperate with the agent (ask it to generate IaC, review code, run checks).
4. You can also invoke the `terraform-checker` skill directly for validation any time (just write `/terraform-checker` in chat).

## Notes

- Keep Terraform conventions in `.claude/rules/terraform.md`.
- Do not duplicate these standards in agent or skill files.
- Use the checker for validation, not for generation.
