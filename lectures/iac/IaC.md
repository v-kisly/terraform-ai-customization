# Infrastructure as Code (IaC) with AI — Expected Lecture Content

## Context

This topic sits under **DevOps** in the **Deployment** phase of the SDLC and is **Required**.

It belongs to **Part 2 (Workflows & Methodology)** and assumes participants already completed **Part 1 (Tools & Foundations)**. In this lecture, Part 1 concepts are applied to a concrete repository that contains both Claude and VS Code Copilot ecosystem files for AI-assisted Terraform delivery.

Each lecture must be delivered as a **slide deck + recorded video**.

---

## 1. Repository-Centered Learning Objective

The lecture must be built around the current codebase, not a generic IaC narrative. Participants should understand how the following assets work together:

| File | Role in the workflow |
|---|---|
| `CLAUDE.md` | High-level workflow and policy source map |
| `.claude/agents/terraform.md` | Agent behavior: requirements, generation flow, validation, severity handling |
| `.claude/rules/terraform.md` | Terraform coding standards and security/tagging requirements |
| `.claude/skills/terraform-checker/SKILL.md` | Validation process and reporting contract |
| `.claude/skills/terraform-checker/terraform-checker.sh` | Runtime checker implementation |
| `.claude/skills/terraform-checker/terraform-checker.yaml` | Enabled checks and execution configuration |

The core educational message is that **agentic IaC is a governed system**, not just prompt-to-code generation.

---

## 2. Applying Part 1 Toolkit to This IaC Ecosystem

| Part 1 Tool | IaC Application in this repository |
|---|---|
| **AI Agents** | The Terraform agent gathers missing inputs, generates Terraform, and coordinates validation |
| **Orchestrator / Subagent Workflows** | Orchestration pattern for requirements -> generation -> checker -> optional plan |
| **MCP Tools** | Access to docs, state, cloud metadata, and operational context for grounded decisions |
| **Skills** | `terraform-checker` as reusable validation capability with standardized output |
| **Planning Mode** | Safe ordering of infra changes and blast-radius-aware remediation planning |
| **Workspaces / Projects** | Persistent context for infrastructure conventions, assumptions, and environment strategy |

The lecture should explicitly compare how the same flow can be executed in Claude-style and Copilot-style agent workflows.

---

## 3. Canonical Delivery Workflow to Teach

The lecture must walk through the repository's canonical flow end to end:

1. Select Terraform agent for provisioning/change task.
2. Gather missing requirements before writing code (region, CIDRs, backend, naming, environment strategy).
3. Generate Terraform files according to `.claude/rules/terraform.md`.
4. Run `terraform-checker` skill and parse findings by severity.
5. Fix all critical findings and handle non-critical findings by risk/context.
6. Run `terraform plan` only on user request.
7. For long plans, keep one terminal session and do not restart while still running.

This sequence should be reinforced as a governance rule, not an optional suggestion.

---

## 4. Requirement Gathering and Clarification Discipline

The lecture must show how AI-driven IaC quality depends on requirement completeness:

- Do not guess critical values (backend parameters, CIDRs, region, naming policy).
- Ask focused clarifying questions before generation.
- Provide at least one recommended option when asking users to choose.

Include practical examples of question sets for backend selection and environment topology.

---

## 5. Terraform Generation Standards to Cover

Teach concrete standards from `.claude/rules/terraform.md`:

- Required module files (`main.tf`, `variables.tf`, `outputs.tf`; `README.md` where applicable)
- Optional supporting files (`providers.tf`, `versions.tf`, `backend.tf`, `locals.tf`, tests)
- 2-space formatting, block ordering, and minimal-change principle
- Version pinning for providers/modules
- Security posture: no hardcoded secrets, least privilege, and tagging policy
- Required common tags (`owner`, `environment`, `cost_center`, `managed_by`) and optional `iac_origin`

The lecture should include at least one before/after snippet showing how these standards improve generated IaC quality.

---

## 6. Validation and Reporting Model

The lecture must present `terraform-checker` as the required validation gate:

- Explain what the skill runs (formatting, validation, linting/security checks per config)
- Explain output artifacts (`terraform-quality-report.md` + concise markdown summary)
- Explain severity normalization and remediation expectations
- Explain that generation/review workflows must not run `terraform apply`

Include a sample findings table with file and line references in the same style used by the skill.

---

## 7. Optional Planning Stage and Async Safety

Teach the planning policy exactly:

- `terraform plan` is optional and runs only when explicitly requested.
- Long-running plan/checker tasks must keep a single active terminal session.
- Do not start duplicate runs while previous execution is still active.
- Treat same-session completion tracking as part of operational reliability.

This should be covered as a real-world failure prevention pattern for AI-assisted operations.

---

## 8. Copilot + Claude Ecosystem Positioning

The lecture should show participants how to reuse the same IaC governance model across tools:

- Claude artifacts provide policy and reusable workflow definitions.
- Copilot chat/agent execution applies those policies inside day-to-day coding sessions.
- Shared standards prevent divergence between assistants.

Highlight that the key value is **consistency of outcomes**, not preference for a single assistant.

---

## 9. Practical Demonstration Requirements

The demo should use repository assets directly:

1. Open `CLAUDE.md` and summarize workflow stages.
2. Open `.claude/agents/terraform.md` and show requirement-first behavior.
3. Open `.claude/rules/terraform.md` and show mandatory standards.
4. Run checker workflow conceptually (or live where possible) using skill docs.
5. Walk through a mock finding and show remediation decision by severity.
6. Show optional plan trigger policy and long-run session discipline.

If execution tools are unavailable during class, still show exact commands and expected outputs.

---

## 10. Key AI Tools to Reference

| Tool | Use Case |
|---|---|
| **GitHub Copilot** | In-editor Terraform authoring, refactoring, and policy-constrained generation |
| **Claude / ChatGPT** | Cross-file reasoning, workflow authoring, and architecture-to-IaC synthesis |
| **MCP Servers** | Access to cloud/state/document context for grounded agent decisions |
| **Terraform CLI + tflint/tfsec/checkov (via checker config)** | Static quality and security validation before planning/apply stages |

---

## 11. Deliverables Alignment

| Artifact | Owner | Relationship |
|---|---|---|
| **Working & Repeatable Infrastructure** | DevOps | Primary lecture outcome |
| **Agent Workflow Definitions** | DevOps / Platform | Encodes repeatable IaC operating model |
| **System Architecture Inputs** | Software Architect | Source inputs for generation and constraints |
| **Quality Gates Policy** | SDET / Security | Validation and severity policy consumed by checker stage |

---

## 12. Summary

Participants should leave with a practical, repeatable model for AI-assisted IaC delivery: gather complete requirements, generate Terraform under shared standards, validate through a reusable checker skill, remediate findings by severity, and run plan only under explicit approval with safe async execution discipline. The lecture must make the repository's Claude and Copilot ecosystem feel like one coherent delivery system.
