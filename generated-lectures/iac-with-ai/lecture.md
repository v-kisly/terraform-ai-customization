# IaC with AI — Comprehensive Lecture

**Course:** Agentic AI in Software Delivery
**Module:** Part 2 — Workflows & Methodology
**Section:** Deployment (DevOps)
**Classification:** Required
**Primary Audience:** DevOps Engineers, Platform Engineers, Software Architects, SREs
**Format:** Slide Deck + Recorded Video

---

## Introduction: Why This Lecture Matters

Most teams already use Terraform, but many still struggle with slow handoffs, inconsistent module quality, and unclear ownership when infrastructure changes move from architecture documents into actual cloud resources. AI can speed up authoring, but speed without guardrails creates bigger operational risk: invalid plans, policy drift, and hidden security mistakes that only show up late in delivery.

This lecture focuses on a practical answer: treat AI-assisted IaC as a governed workflow, not as ad-hoc prompting. In this repository, that workflow is explicit. `CLAUDE.md` defines the delivery sequence, `.claude/agents/terraform.md` enforces requirement-first behavior, `.claude/rules/terraform.md` defines coding/security standards, and `.claude/skills/terraform-checker/*` provides a reusable validation gate.

By the end, you should be able to run a repeatable loop: gather requirements, generate Terraform with standards, validate through checker outputs, remediate by severity, and only run `terraform plan` when explicitly requested. That is the difference between “AI writes code” and “AI supports production-grade infrastructure delivery.”

---

## Part 1 Tool Recap: How the Agentic AI Toolkit Maps to IaC with AI

| Part 1 Tool | Concrete Application in This Topic |
|---|---|
| AI Agents | The Terraform agent gathers missing infrastructure inputs and generates standards-compliant Terraform files. |
| Orchestrator / Subagent Workflows | A top-level flow enforces ordered phases: requirements -> generation -> validation -> optional planning. |
| MCP Tools | MCP can provide live context (state, cloud metadata, architecture docs) to ground generation and troubleshooting decisions. |
| Skills | The `terraform-checker` skill codifies quality checks and reporting outputs for repeatable validation. |
| Planning Mode | AI proposes safe change order, blast radius thinking, and remediation sequence before risky operations. |
| Workspaces / Projects | Persistent project context preserves conventions, assumptions, and environment strategy across sessions. |

AI Agents are valuable here because the repository already encodes behavior expectations. The agent in `.claude/agents/terraform.md` does not start from code generation; it starts from requirement discovery. That single design choice reduces rework by preventing invalid assumptions about CIDRs, backend details, and naming.

Orchestration matters because IaC workflows have natural checkpoints. Infrastructure generation without a validation phase is incomplete. The canonical sequence in `CLAUDE.md` makes those checkpoints explicit and auditable, which gives teams a shared operating model regardless of whether they execute through Claude or Copilot.

MCP Tools become critical when you move from static files to operational environments. Instead of guessing current state, agents can inspect state and metadata, compare declared and actual infrastructure, and prepare safer remediation options. This is especially useful for drift analysis and incident recovery.

Skills make quality repeatable. The `terraform-checker` skill documents what should run, what output should be produced, and how to summarize findings with severity and file references. This prevents “it passed on my machine” quality drift between contributors.

Planning Mode is not optional for significant changes. It introduces dependency ordering and blast-radius awareness before execution. In infrastructure work, this planning step is often the difference between a controlled rollout and a cascading incident.

Workspaces and project memory stabilize long-running initiatives. Infrastructure delivery spans many sessions, environments, and reviewers. Persisted context allows AI assistants to maintain continuity in standards, assumptions, and remediation logic.

---

## Repository Blueprint: Claude + VS Code Copilot IaC Ecosystem

The repository has a clean separation of concerns. `CLAUDE.md` is the high-level contract: what workflow exists and what must happen before completion. `.claude/rules/terraform.md` is the single policy source for Terraform standards. `.claude/agents/terraform.md` is orchestration behavior: what the agent must ask, do, and enforce. `.claude/skills/terraform-checker/SKILL.md` and its adjacent script/config files define validation execution and reporting expectations.

This architecture avoids a common anti-pattern: duplicating standards in multiple places. Instead of hardcoding formatting, security, and file requirements inside every prompt or agent instruction, standards live once in `.claude/rules/terraform.md`. Agents and skills reference that source, so updates propagate consistently.

For Copilot-oriented execution, this same structure remains useful. Copilot can read the same markdown artifacts to apply identical governance in daily implementation. That gives organizations cross-assistant consistency: different interfaces, same policy outcomes.

---

## End-to-End Workflow: Requirements -> Generate -> Validate -> (Optional) Plan

Step 1 is agent selection and task framing. For infrastructure changes, invoke the Terraform specialist behavior and describe the desired outcome in concrete terms: target environment, cloud provider, scope boundaries, and non-functional constraints.

Step 2 is requirement gathering. Before generating resources, the workflow asks for missing values such as region, CIDRs, backend selection, naming conventions, and environment strategy. This is enforced in `.claude/agents/terraform.md` to prevent speculative configuration.

Step 3 is code generation under standards. The agent creates Terraform files (`main.tf`, `variables.tf`, `outputs.tf`, plus supporting files where relevant) using guidance from `.claude/rules/terraform.md`. The goal is minimal, targeted changes rather than broad refactoring.

Step 4 is checker validation. The `terraform-checker` skill executes configured quality tools and emits both a raw report and a concise findings summary. File and line references support direct remediation.

Step 5 is severity-driven remediation. Critical issues are mandatory to fix before completion. High/medium/low findings are handled by context and risk, with explicit deferral rationale where needed.

Step 6 is optional planning. `terraform plan` runs only on explicit request. For long runs, the workflow must keep one terminal session active and avoid duplicate plan invocations until completion is confirmed.

---

## Requirement Gathering Discipline: Why It Is a First-Class IaC Practice

Infrastructure defects often begin as requirement defects. If backend parameters are incomplete or CIDR boundaries are assumed, generated code may look syntactically correct while still failing operationally. The repository workflow addresses this by forcing requirement completeness before code generation.

A practical approach is to ask grouped clarification questions by concern area: environment topology, networking, backend/state, naming/tagging, and compliance constraints. Each question should include at least one recommended option so decision-making remains fast and guided.

Example: backend selection can be framed as a constrained choice among HCP Terraform/Terraform Cloud, S3 + DynamoDB, Azure Blob, GCS, or local backend. The recommendation should align with collaborative environments and locking requirements, while local backend should be positioned as an explicit exception.

---

## Terraform Generation Standards from .claude/rules/terraform.md

The rules file establishes mandatory structure and formatting conventions. Every module includes `main.tf`, `variables.tf`, and `outputs.tf`; root or reusable modules also include `README.md`. Supporting files such as `providers.tf`, `versions.tf`, `backend.tf`, and `locals.tf` are added when needed.

Versioning rules are explicit: provider and module versions must be constrained. Security posture is also explicit: no hardcoded secrets, least-privilege defaults, and consistent tagging. The `common_tags` pattern requires `owner`, `environment`, `cost_center`, and `managed_by = "terraform"`, with optional `iac_origin` included only when non-empty.

The minimal-change rule is important for maintainability. AI should not perform broad rewrites when a focused update solves the task. This keeps diffs reviewable and lowers regression risk in shared infrastructure repositories.

---

## Validation as a Quality Gate: terraform-checker Skill

The checker skill is the mandatory static quality gate after Terraform changes. It is not a generation tool and not an apply tool. Its purpose is to run configured checks, produce raw output in `terraform-quality-report.md`, and present a concise markdown findings summary.

The skill definition also includes execution reliability guidance for long-running tasks. Because tools may initialize providers or pull docker images, the workflow should treat checker execution as potentially blocking and avoid duplicate concurrent invocations.

A best-practice summary format is:

| Severity | Tool | File | Line | Finding | Recommended fix |
|---|---|---|---|---|---|
| high | tfsec | network.tf | 41 | Public ingress on 0.0.0.0/0 for admin port | Restrict ingress CIDRs and separate admin access path |
| medium | tflint | variables.tf | 12 | Variable description missing | Add clear variable description for maintainability |
| low | fmt | main.tf | n/a | Formatting drift | Run formatter and commit normalized HCL |

This format makes remediation planning straightforward for both humans and agents.

---

## Severity-Driven Remediation and Governance

Not all findings should be treated equally, but all findings should be visible. Critical findings are hard blockers and must be fixed before considering work complete. Non-critical findings can be deferred when justified by scope, risk tolerance, or release constraints.

What matters operationally is explicit decision logging. If a medium finding is deferred, the workflow should document why, who accepted the tradeoff, and what follow-up is expected. This creates auditability and prevents silent normalization of risk.

This governance model aligns AI behavior with team reliability goals. The assistant proposes and accelerates, but human owners preserve accountability for production-impacting decisions.

---

## Optional terraform plan and Async Session Safety

The repository defines a strict rule: `terraform plan` is optional and runs only on explicit user request. This avoids unnecessary cloud/API operations during routine generation and review work.

When plan is requested, operational discipline matters. Long-running plan executions must stay in a single terminal session until completion. Starting another plan while one is still active can create confusion, lock contention, and misleading status signals.

In practice, this means: launch one plan, monitor the same session output, wait for process completion, and only then decide whether another run is necessary. The same principle applies to long checker runs and other state-sensitive operations.

---

## SDLC Document Chain Integration for IaC Delivery

IaC delivery consumes architecture artifacts across multiple SDD sections. Service profile and data design shape compute and persistence resources. Security and compliance sections shape IAM, encryption, and network boundaries. Environment strategy informs tfvars structure and deployment parity.

Observability and SLA sections influence monitoring resources and scaling policies. CI/CD sections influence pipeline infrastructure requirements. Integration sections define external connectivity and dependency constraints.

AI works best when this document chain is explicit and accessible. With MCP-backed document/context access, agents can generate infrastructure that is traceable to architecture intent rather than disconnected from design decisions.

---

## Practical Demo Walkthrough

1. Open `CLAUDE.md` and explain the canonical Terraform workflow stages in order.
2. Open `.claude/agents/terraform.md` and highlight requirement-first behavior and completion criteria.
3. Open `.claude/rules/terraform.md` and point out module file requirements, tagging rules, and security expectations.
4. Open `.claude/skills/terraform-checker/SKILL.md` and explain expected outputs and severity table format.
5. Run a mock scenario where an AI-generated Terraform change produces three findings (high/medium/low), then narrate remediation decisions.
6. Demonstrate plan policy: show that plan is only triggered by explicit request and must complete in one session for long runs.

During the demo, emphasize that this is an operating model participants can copy into their own repos: one source of standards, one agent behavior contract, one validation skill contract.

---

## Hands-On Exercise

1. Create a short architecture brief for a service that needs VPC networking, one database, and basic monitoring in dev and prod.
2. Use an AI assistant to generate Terraform scaffolding aligned to required files (`main.tf`, `variables.tf`, `outputs.tf`).
3. Add tagging and variable conventions from `.claude/rules/terraform.md`, including required common tags and optional `iac_origin` handling.
4. Run a checker simulation (or actual checker if environment allows) and collect findings in the severity table format.
5. Fix all critical findings and document decisions for one non-critical deferred item.
6. Trigger `terraform plan` only if your reviewer explicitly asks for it; otherwise stop at validated static quality.
7. Write a short retrospective: what requirements were initially missing, which checks caught real risks, and how the workflow reduced ambiguity.

Expected outcome: a standards-aligned mini IaC package plus a traceable quality/remediation record.

---

## Limitations and Risks

AI assistants can still generate plausible but context-misaligned infrastructure. If architecture inputs are incomplete or stale, generated code can be “clean” yet operationally wrong. Human review remains essential for domain constraints, cost exposure, and compliance interpretation.

Static checks are necessary but not sufficient. A checker can catch many misconfigurations, but it cannot replace environment-specific verification, quota awareness, or organizational approval policies. Teams should treat checker success as a gate, not as proof of production readiness.

Prompt drift and policy drift are long-term risks. Without a single source of standards and regular maintenance of agent/skill instructions, outputs diverge across assistants and contributors. The repository structure shown in this lecture is designed to reduce that drift, but it still requires stewardship.

---

## Key Takeaways

- AI-assisted IaC is most reliable when implemented as a governed workflow, not a one-shot prompt.
- This repository models clear separation: standards (`.claude/rules`), orchestration (`.claude/agents`), and validation (`.claude/skills`).
- Requirement gathering is a hard quality gate; missing inputs create expensive downstream failures.
- `terraform-checker` style validation with severity and file/line reporting makes remediation actionable.
- Critical findings are non-negotiable blockers; non-critical findings still require explicit decisions.
- `terraform plan` should be optional, approval-driven, and session-safe for long executions.
- The same governance model can be reused across Claude and VS Code Copilot to keep outcomes consistent.
