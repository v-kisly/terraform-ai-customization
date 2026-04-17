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

If the target directory is missing or does not contain Terraform files, stop and report that the skill could not run.

## Platform Detection (AI Responsibility)

Use the checker script:
- `./terraform-checker.sh`

The script reads only an external `terraform-checker.yaml` (or `terraform-checker.yml`) located in the same directory as the script. If `yq` is installed it uses `yq` for parsing; otherwise it falls back to the built-in YAML parser.

## Quick Start

### Linux & macOS

```bash
./terraform-checker.sh /path/to/terraform
```

### Async Execution (Critical for AI/Automation)

**DO NOT** invoke this script multiple times concurrently. It is designed as a long-running blocking task.

When using async execution in automation:

1. **Use async mode** with timeout >= 30,000 ms
2. **Capture the terminal ID** from the initial response
3. **Poll output repeatedly** with `get_terminal_output()` using that ID
4. **Wait for completion** until the shell prompt (`$`) appears
5. **Do NOT invoke again** until the previous execution shows the shell prompt

**Why?** This script:
- Holds file locks (`.terraform.lock.hcl`)
- Runs `terraform init` which downloads providers (slow, ~30s on first run)
- Pulls Docker images on first run (60+ seconds)
- Conflicts if invoked before cleanup

**Expected durations:**
- Without Docker-based tools enabled in config: 15-30 seconds
- With Docker-based tools enabled: 60-120 seconds
- First run (provider downloads): add +20s

**Example (pseudo-code):**
```
terminal_id = run_async("bash ./terraform-checker.sh ./my-tf", timeout=30000)
while not done:
    output = get_terminal_output(terminal_id)
    if "$" in output and "All checks" in output:
        done = true
    sleep(2)
```

## Options

### Bash Script

```bash
terraform-checker.sh [terraform_directory]
```

- No flags are supported.
- Tool execution is controlled only through `terraform-checker.yaml` in the script directory.

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
2. Load the external YAML tool list from `terraform-checker.yaml` next to `terraform-checker.sh`
3. Parse YAML through `yq` when available, otherwise through the script's internal parser
4. Validate that the config contains `settings.report_file` and at least one enabled tool with commands
5. Execute enabled tools in declaration order
6. Write raw tool output into the configured report file

Keep the execution read-only with respect to infrastructure lifecycle. Never run `terraform apply`, `terraform destroy`, or state mutation commands.

## Failure Handling

- If Docker is unavailable for a Docker-based tool: Record in report and continue
- If Terraform CLI is missing: Report error and exit
- If the YAML config is missing or invalid: Report the configuration error and exit
- On tool failures: Include error details in the configured report file

## Reporting Rules

- Prefer file and line references when the underlying tool emits them.
- Deduplicate repeated findings when they refer to the same issue.
- Classify findings conservatively; do not label style issues as `high`.
- Mention skipped tools explicitly so the user can judge coverage.

## Troubleshooting

### Script hangs or appears to loop

**Symptom:** Script is stuck on `terraform init` or Docker pull, or you see multiple invocations running.

**Causes:**
1. **Previous execution still running** - invoked script before previous completed
2. **terraform init downloading providers** - normal, takes 30+ seconds first time
3. **Docker pulling image** - normal, takes 60+ seconds first time
4. **Network issue** - provider registry or Docker registry unreachable

**Solution:**
- Disable Docker-based tools in `terraform-checker.yaml` for faster development checks
- Wait longer (watch terminal output with `get_terminal_output()` repeatedly)
- Use a separate terminal to check if `terraform init` is running: `ps aux | grep terraform`
- Ensure script completes (shell prompt `$` appears) before invoking again

### Script exits with "No Terraform files found"

**Solution:** Pass the correct path to the Terraform directory:
```bash
./terraform-checker.sh ./environments/dev  # correct
./terraform-checker.sh .                   # wrong if run from script directory
```

### Config file not found

**Solution:** Place `terraform-checker.yaml` (or `terraform-checker.yml`) in the same directory as `terraform-checker.sh`.

### Docker-based tools fail

**Solution:** Either:
- Install Docker and ensure it's running
- Disable the Docker-based tools in `terraform-checker.yaml`
