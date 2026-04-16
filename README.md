# Terraform AI Customization

This stack is made for repositories that use Terraform for infrastructure provisioning and want to integrate AI into their Terraform workflows. It includes a Terraform agent for requirement gathering and workflow orchestration, shared instructions for repository-wide Terraform standards, and a Terraform checker skill for validation.

The goal of this setup is simple:
- keep Terraform generation disciplined;
- force requirement collection before code generation;
- centralize Terraform conventions in one place;
- validate generated code with a reusable skill instead of ad hoc commands.

## What is included

### Terraform agent

File: `agents/terraform.agent.md`

This is a dedicated infrastructure agent for Terraform work. It is intended to be selected when the task is about provisioning or changing infrastructure.

Main responsibilities:
- collect missing infrastructure requirements before writing code;
- reuse existing modules and conventions from the repository when possible;
- keep backend selection explicit;
- avoid unsafe assumptions about regions, CIDRs, names, instance sizes, and state backends;
- delegate validation to the Terraform checker skill.

In practice, this agent acts as the workflow coordinator. It does not try to duplicate all Terraform conventions in the agent file itself. Instead, it points to the shared Terraform instructions and then invokes the validation skill when code changes are made.

### Shared Terraform instructions

File: `instructions/terraform.instructions.md`

This file contains reusable Terraform repository guidance, including:
- required and recommended Terraform file structure;
- formatting conventions;
- naming and module organization;
- provider and module version pinning;
- backend and state guidance;
- security expectations;
- validation workflow expectations.

These instructions are the policy layer for Terraform work. The agent should follow them rather than restating them.

### Terraform checker skill

Files:
- `skills/terraform-checker/SKILL.md`
- `skills/terraform-checker/terraform-checker.ps1`
- `skills/terraform-checker/terraform-checker.sh`
- `skills/terraform-checker/terraform-checker.ini`

This skill is responsible for Terraform quality checks. It is designed for validation, not generation.
Script behavior and checker toggles can be customized in `skills/terraform-checker/terraform-checker.ini`.

Main responsibilities:
- run `terraform init -backend=false -input=false`;
- run `terraform validate`;
- run `terraform fmt -check -recursive`;
- run Docker-based `tflint` and `tfsec` when enabled;
- write a raw report to `terraform-quality-report.md` in the target Terraform directory;
- return a concise chat summary with normalized severities.

## How the pieces work together

Recommended flow:
1. Select the Terraform agent for an infrastructure task.
2. Let the agent gather required inputs first.
3. The agent follows the Terraform instructions file for repository standards.
4. After code is generated or changed, the agent runs the Terraform checker skill.
5. The skill produces validation output and the agent reports remaining assumptions or follow-up work.

This separation keeps responsibilities clear:
- the agent drives the workflow;
- the instructions define standards;
- the skill performs repeatable validation.

## How to use this setup

### In VS Code

Use this setup when working with GitHub Copilot customizations in VS Code.

Typical workflow:
1. Open Chat or Agent mode.
2. Select the `Terraform Agent` from the agents list.
3. Describe the infrastructure you want to provision or update.
4. Answer the agent's clarifying questions.
5. Review the generated Terraform changes.
6. Run or ask the agent to run the Terraform checker skill against the target Terraform directory.

Use the skill directly when you only need validation. For example, invoke the Terraform checker skill for an existing module or root configuration.

Example prompts:

```text
/terraform-checker .
```

```text
Run the terraform-checker skill for ./infra and include Docker-based checks.
```

```text
Run the terraform-checker skill for ./modules/network with Docker checks skipped.
```

### In Claude Code

Claude Code does not read `.agent.md` files from `.github/agents` as its primary instruction mechanism. Its main persistent mechanism is `CLAUDE.md` plus optional `.claude/rules`, `.claude/agents`, and `.claude/skills` directories.

If you want Claude Code to use the same repository guidance, the practical approach is:
1. Create a project `CLAUDE.md` or `.claude/CLAUDE.md`.
2. Import shared guidance from this folder, for example `@.github/instructions/terraform.instructions.md`.
3. Optionally mirror the agent and skill into Claude-compatible locations.

Example `CLAUDE.md` excerpt:

```md
@.github/instructions/terraform.instructions.md

# Terraform workflow
- Use the Terraform validation skill after Terraform changes.
- Ask for missing backend, region, CIDR, and naming inputs before generation.
```

That keeps one shared source of Terraform policy while still using Claude-native loading behavior.

Example Claude-friendly prompt:

```text
Use the terraform-checker skill for ./infra and summarize all findings by severity.
```

## Supported file locations

This section focuses on practical locations that work today, including recursive folder layouts where supported.

### VS Code locations

#### Always-on repository instructions

Recommended options:
- `.github/copilot-instructions.md`
- `AGENTS.md`
- `CLAUDE.md`
- `.claude/CLAUDE.md`

Notes:
- `copilot-instructions.md` is the clearest GitHub Copilot repository-wide default.
- `AGENTS.md` is useful when you want one shared always-on file for multiple agents.
- VS Code also understands `CLAUDE.md` for Claude compatibility.

#### File-scoped instructions

Default workspace locations that VS Code scans recursively:
- `.github/instructions/**/*.instructions.md`
- `.claude/rules/**/*.md`

Examples:

```text
.github/
  instructions/
    terraform/
      terraform.instructions.md
    security/
      iam.instructions.md
    modules/aws/
      tagging.instructions.md
```

```text
.claude/
  rules/
    terraform.md
    terraform/
      aws.md
      azure.md
```

Important note for this repository:
- the Terraform instructions file now lives at `.github/instructions/terraform.instructions.md`;
- this matches the default VS Code workspace discovery path for `.instructions.md` files;
- if you prefer another location, configure it with `chat.instructionsFilesLocations`.

#### Custom agents

Default workspace locations:
- `.github/agents/**/*.agent.md`
- `.claude/agents/**/*.md`

Examples:

```text
.github/
  agents/
    terraform.agent.md
    review.agent.md
    platform/
      networking.agent.md
```

```text
.claude/
  agents/
    terraform.md
    platform/
      networking.md
```

#### Skills

Default workspace locations:
- `.github/skills/<skill-name>/SKILL.md`
- `.claude/skills/<skill-name>/SKILL.md`
- `.agents/skills/<skill-name>/SKILL.md`

Examples:

```text
.github/
  skills/
    terraform-checker/
      SKILL.md
      terraform-checker.ps1
      terraform-checker.sh
      terraform-checker.ini
```

```text
.claude/
  skills/
    terraform-checker/
      SKILL.md
      terraform-checker.ps1
```

### Claude Code locations

#### Main project instructions

Working options:
- `CLAUDE.md`
- `.claude/CLAUDE.md`
- `CLAUDE.local.md` for local-only personal overrides

Behavior:
- Claude Code loads project-level `CLAUDE.md` files from the current directory and parent directories;
- nested `CLAUDE.md` files inside subdirectories load on demand when Claude reads files in those subdirectories;
- `CLAUDE.local.md` is useful for personal, non-committed overrides.

Examples:

```text
repo/
  CLAUDE.md
  infra/
    CLAUDE.md
  modules/
    network/
      CLAUDE.md
```

or

```text
repo/
  .claude/
    CLAUDE.md
    rules/
      terraform.md
      terraform/
        aws.md
        modules.md
```

#### Path-scoped rules

Recommended location:
- `.claude/rules/**/*.md`

Rules can be global or scoped with YAML frontmatter using `paths`.

Example:

```md
---
paths:
  - "infra/**/*.tf"
  - "modules/**/*.tf"
---

# Terraform Rules

- Use 2-space indentation.
- Pin provider versions.
- Never hardcode secrets.
```

#### Claude agents and skills

Working locations:
- `.claude/agents/**/*.md`
- `.claude/skills/<skill-name>/SKILL.md`

These are useful when you want Claude-native reusable agent roles and on-demand workflows instead of only a single `CLAUDE.md` file.

## Recommended cross-tool layout

If you want one repository to work well in both VS Code and Claude Code, this structure is practical:

```text
.github/
  README.md
  agents/
    terraform.agent.md
  instructions/
    terraform.instructions.md
  skills/
    terraform-checker/
      SKILL.md
      terraform-checker.ps1
      terraform-checker.sh
      terraform-checker.ini

.claude/
  CLAUDE.md
  rules/
    terraform.md
  agents/
    terraform.md
  skills/
    terraform-checker/
      SKILL.md
```

Why this layout works:
- VS Code can discover agents, instructions, and skills in its default repository locations;
- Claude Code can load project instructions from `.claude/CLAUDE.md` and path-scoped rules from `.claude/rules/`;
- the repository can keep shared Terraform guidance in one place and mirror only what is necessary.

## Maintenance guidance

- Keep the agent focused on workflow and decision-making.
- Keep the instructions file focused on standards and policy.
- Keep the skill focused on repeatable execution steps.
- Prefer small, topic-specific rule files over one very large rule document.
- When you need automatic discovery in VS Code, place `.instructions.md` files under `.github/instructions/` unless you explicitly configured extra locations.
- When you need Claude compatibility, prefer `CLAUDE.md` and `.claude/rules/` instead of relying on `.github` alone.

## Summary

This `.github` folder defines a Terraform-oriented AI workflow:
- `agents/terraform.agent.md` is the operator;
- `instructions/terraform.instructions.md` is the policy source;
- `skills/terraform-checker/` is the validation mechanism.

If you want the same workflow to work cleanly in both VS Code and Claude Code, use `.github` for Copilot-native assets and `.claude` for Claude-native assets, with shared guidance linked or mirrored between them.
