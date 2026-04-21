# IaC with AI — Slide Deck Outline

---

## Slide 1: IaC with AI in Agentic Software Delivery
**Type:** Title
**What to present:**
- Course, module, and section context: Part 2, DevOps, Deployment phase
- Lecture promise: from AI prompting to governed infrastructure workflow
- Visual suggestion: clean title slide with workflow icon strip (Agent, Rules, Skill, Plan)

---

## Slide 2: Why Teams Still Struggle with IaC Delivery
**Type:** Content
**What to present:**
- Pain points: inconsistent modules, late security findings, unclear ownership
- Why "AI writes Terraform" is not enough without quality gates
- Visual suggestion: problem/impact table with latency, risk, rework columns

---

## Slide 3: Learning Outcomes for This Session
**Type:** Content
**What to present:**
- Build a repeatable requirements -> generation -> validation workflow
- Apply repository standards to generated Terraform artifacts
- Use severity-driven remediation and optional plan policy
- Visual suggestion: checklist graphic with three outcomes

---

## Slide 4: Section Divider — Repository Blueprint
**Type:** Section divider
**What to present:**
- Transition to concrete repository assets
- Emphasize "real files, real workflow"
- Visual suggestion: divider with repo tree silhouette

---

## Slide 5: Repository Anatomy for AI-Assisted IaC
**Type:** Content
**What to present:**
- `CLAUDE.md` as workflow map
- `.claude/agents/terraform.md` as behavior contract
- `.claude/rules/terraform.md` and checker skill files as policy + validation layer
- Visual suggestion: architecture diagram of file relationships

---

## Slide 6: Separation of Concerns by Design
**Type:** Content
**What to present:**
- Standards live once in rules, not duplicated in prompts
- Agent orchestrates flow, skill validates quality
- Copilot and Claude can share the same governance model
- Visual suggestion: three-layer stack diagram (Policy, Orchestration, Validation)

---

## Slide 7: Section Divider — Part 1 Toolkit Mapping
**Type:** Section divider
**What to present:**
- Transition to mapping Part 1 foundations to IaC execution
- Visual suggestion: divider with toolkit icons

---

## Slide 8: Mapping Part 1 Tools to IaC Operations
**Type:** Content
**What to present:**
- Table mapping agents, orchestrator, MCP, skills, planning mode, workspaces
- Concrete examples for each row from this repository
- Visual suggestion: full mapping table screenshot

---

## Slide 9: AI Agents and Orchestration in Practice
**Type:** Content
**What to present:**
- Requirement-first behavior before generation starts
- Ordered workflow checkpoints and completion criteria
- Visual suggestion: sequence diagram from user request to validated output

---

## Slide 10: MCP, Skills, and Persistent Context
**Type:** Content
**What to present:**
- MCP for grounded state/doc context
- `terraform-checker` as reusable skill contract
- Workspace/project memory for long-lived infra initiatives
- Visual suggestion: context flow diagram (Docs/State -> Agent -> Actions)

---

## Slide 11: Section Divider — Canonical Delivery Workflow
**Type:** Section divider
**What to present:**
- Transition to the end-to-end operational sequence
- Visual suggestion: horizontal pipeline banner

---

## Slide 12: Workflow Stage 1 — Gather Requirements
**Type:** Content
**What to present:**
- Required inputs: region, CIDRs, backend, naming, environments
- Why guessing causes downstream failures
- Visual suggestion: form-style checklist for required inputs

---

## Slide 13: Workflow Stage 2 — Generate Terraform with Standards
**Type:** Content
**What to present:**
- Required files: `main.tf`, `variables.tf`, `outputs.tf`
- Supporting files where applicable: providers/versions/backend/locals/tests
- Visual suggestion: generated module file tree screenshot

---

## Slide 14: Workflow Stage 3 — Validate via terraform-checker
**Type:** Content
**What to present:**
- Checker outputs: raw report + concise findings summary
- Severity normalization and file/line remediation flow
- Visual suggestion: sample findings table with severity colors

---

## Slide 15: Workflow Stage 4 — Optional terraform plan Policy
**Type:** Content
**What to present:**
- Plan only on explicit request
- One-session execution rule for long-running plans
- Visual suggestion: do/don't comparison panel

---

## Slide 16: Section Divider — Standards Deep Dive
**Type:** Section divider
**What to present:**
- Transition into rules from `.claude/rules/terraform.md`
- Visual suggestion: policy binder graphic

---

## Slide 17: Terraform Standards That Matter Most
**Type:** Content
**What to present:**
- Minimal-change principle and readable diffs
- 2-space formatting and block organization
- Version constraints and compatibility discipline
- Visual suggestion: before/after code snippet comparison

---

## Slide 18: Security and Tagging Baseline
**Type:** Content
**What to present:**
- No hardcoded secrets and least-privilege defaults
- Required common tags and optional `iac_origin`
- Why tagging quality affects governance and cost visibility
- Visual suggestion: tag map snippet with required vs optional keys

---

## Slide 19: Section Divider — Risk and Remediation
**Type:** Section divider
**What to present:**
- Transition to findings triage and governance
- Visual suggestion: risk matrix backdrop

---

## Slide 20: Severity-Driven Remediation Model
**Type:** Content
**What to present:**
- Critical findings as blockers
- Handling high/medium/low by risk and context
- Explicit deferral rationale for non-critical findings
- Visual suggestion: triage decision tree

---

## Slide 21: Common Failure Modes in AI-Assisted IaC
**Type:** Content
**What to present:**
- Missing requirements, policy drift, and async execution mistakes
- Why checker success is necessary but not sufficient
- Visual suggestion: failure mode table (symptom -> root cause -> control)

---

## Slide 22: Section Divider — Live Demonstration
**Type:** Section divider
**What to present:**
- Transition to a guided walkthrough
- Visual suggestion: terminal + editor split mockup

---

## Slide 23: Demo Walkthrough — From Files to Workflow
**Type:** Demo
**What to present:**
- Open key files in order and narrate workflow ownership
- Simulate a checker finding and remediation choice
- Show optional plan trigger point and session-safety rule
- Visual suggestion: live IDE navigation + terminal output

---

## Slide 24: Hands-On Exercise — Build a Mini IaC Workflow
**Type:** Exercise
**What to present:**
- Short architecture brief to Terraform scaffolding
- Apply standards, produce findings table, fix critical items
- Optional plan only with explicit reviewer request
- Visual suggestion: exercise worksheet with deliverables box

---

## Slide 25: Key Takeaways and Next Actions
**Type:** Summary
**What to present:**
- Governance-first AI IaC model
- Reusable cross-assistant standards for consistent outcomes
- What to implement in your team this week
- Visual suggestion: 7-point takeaway list with action badges
