---
name: terraform-checker
description: "Use when checking Terraform quality: run terraform fmt/validate and tflint/tfsec scans, then return findings as a concise markdown table with file and line references."
---

# Terraform Checker Skill

## Purpose

Run Terraform static quality checks for an existing Terraform directory and return a compact, remediation-oriented report.

Use this skill when:
- reviewing generated Terraform code;
- validating a Terraform module or root module before handoff;
- checking formatting, validation, linting, or security findings.

Do not use this skill for:
- generating Terraform code;
- applying infrastructure changes;
- backend migrations or state operations.

## Inputs

Required input:
- Target Terraform directory.

Optional input:
- Whether Docker-based checks should be skipped.

If the target directory is missing or does not contain Terraform files, stop and report that the skill could not run.

## Platform Detection (AI Responsibility)

The AI chooses the appropriate script based on the system:
- **Linux/macOS**: `terraform-checker.sh`
- **Windows**: `terraform-checker.ps1`

## Quick Start

### Linux & macOS

```bash
./terraform-checker.sh /path/to/terraform
```

### Windows (PowerShell)

```powershell
.\terraform-checker.ps1 -TerraformDir "C:\path\to\terraform"
```

## Options

### Bash Script

```bash
./terraform-checker.sh [terraform_directory] [--skip-docker]
```

### PowerShell Script

```powershell
.\terraform-checker.ps1 -TerraformDir "path\to\terraform" [-SkipDocker]
```

- `--skip-docker` / `-SkipDocker`: Skip Docker-based checks (tflint, tfsec)

## Outputs

The skill must produce both outputs below:

1. `terraform-quality-report.md` in the target directory with raw scan details.
2. A concise markdown summary in chat using this column set:

| Severity | Tool | File | Line | Finding | Recommended fix |
|----------|------|------|------|---------|-----------------|

Severity should be normalized to `high`, `medium`, `low`, or `info`.

If a tool does not provide file or line data, use `n/a`.

If no findings are detected, return a short success message and mention any skipped checks.

## Workflow

1. Change to the Terraform directory
2. Initialize providers: `terraform init -backend=false -input=false`
3. Validate configuration: `terraform validate`
4. Check formatting: `terraform fmt -check -recursive`
5. Run TFLint (Docker): `docker run ... ghcr.io/terraform-linters/tflint:latest`
6. Run tfsec (Docker): `docker run ... aquasec/tfsec:latest`

Keep the execution read-only with respect to infrastructure lifecycle. Never run `terraform apply`, `terraform destroy`, or state mutation commands.

## Failure Handling

- If Docker is unavailable: Record in report and continue (or use `--skip-docker`)
- If Terraform CLI is missing: Report error and exit
- On tool failures: Include error details in `terraform-quality-report.md`

## Reporting Rules

- Prefer file and line references when the underlying tool emits them.
- Deduplicate repeated findings when they refer to the same issue.
- Classify findings conservatively; do not label style issues as `high`.
- Mention skipped tools explicitly so the user can judge coverage.
