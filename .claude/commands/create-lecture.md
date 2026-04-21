# Create Lecture

Generate a complete educational lecture package for the "Agentic AI in Software Delivery" course, grounded in this repository's Claude and VS Code Copilot IaC ecosystem.

**Usage:** `/create-lecture <topic name>`

**Extended usage:** `/create-lecture <topic name> | <what should be covered>`

**Examples:**
- `/create-lecture IaC with AI`
- `/create-lecture IaC with AI | cover Claude/Copilot workflow, requirement gathering, Terraform generation standards, checker validation, async plan safety, and demo steps`

---

## Instructions

The user has provided: **$ARGUMENTS**

### Step 0 — Handle missing topic

If `$ARGUMENTS` is empty or blank, do the following **before anything else**:

1. List the contents of the `lectures/` folder.
2. Collect every **subfolder name** directly inside `lectures/` (ignore files).
3. Present those subfolder names to the user as a numbered list and ask them to pick one or type a custom topic. Do not invent or suggest any topics that are not represented by an actual subfolder — the list must come entirely from what exists on disk.
4. Wait for the user's selection, then continue with the chosen topic name as if it had been passed as `$ARGUMENTS`.

Do **not** show a hardcoded or inferred list of topics. The options must always reflect the real subfolders in `lectures/` at the time the command is run.

---

Parse the input: everything before the `|` is the **topic name**, everything after is **content guidance** (what should be covered). If there is no `|`, treat the full input as the topic name and infer the content from the course README and lectures spec.

---

### Step 1 — Load course context

Read the following files to ground the lecture in the actual repository workflow:
- `README.md` — course overview, SDLC phases, and part structure
- `CLAUDE.md` — Terraform AI customization overview and canonical workflow
- `.claude/agents/terraform.md` — Terraform agent behavior and operating rules
- `.claude/rules/terraform.md` — repository Terraform standards
- `.claude/skills/terraform-checker/SKILL.md` — checker behavior and reporting format
- `.claude/skills/terraform-checker/terraform-checker.yaml` — enabled checks and execution model
- `.claude/skills/terraform-checker/terraform-checker.sh` — executable checker logic

Then slugify the topic name (lowercase, hyphens, no special chars) and look for matching topic specs under `lectures/`:
- First check `lectures/{slug}/`
- If that does not exist, check semantically close folders (for example, `lectures/iac/` for "IaC with AI")
- Read **all files** inside the selected folder

Treat lecture topic files under `lectures/` as authoritative for expected learning outcomes, and use `.claude/*` files as authoritative for implementation details and workflows.

Identify where this topic sits in the course:
- Which SDLC phase does it belong to?
- Is it Part 1 (Tools & Foundations) or Part 2 (Workflows & Methodology)?
- Which roles are the primary audience?
- Is it marked Required or Optional in the README?

---

### Step 2 — Web research

Perform targeted web searches to gather practical, current context:
- The most current AI tools relevant to AI-assisted IaC (names, vendors, what they do)
- Real-world use cases and operating patterns from 2024-2026
- Notable limitations or failure modes practitioners report
- How the external landscape maps back to this repo's toolkit (agents, MCP tools, skills, orchestrator/subagent workflows, planning mode, workspaces)

Use search queries like:
- `"AI-assisted [topic]" 2024 2025 tools`
- `"[topic] AI agents" real-world examples`
- `[specific tool names from README] [topic] workflow`

If web access is limited, proceed with repository-grounded content and explicitly avoid unsupported claims.

---

### Step 3 — Determine output folder

- Slugify the topic name (lowercase, hyphens, no special chars)
- Output folder: `generated-lectures/{slug}/`
- Create three files inside that folder (see Step 4–6)

---

### Step 4 — Generate Artifact 1: Comprehensive Lecture (`lecture.md`)

Write a thorough, prose-heavy lecture document. This is the source of truth — the equivalent of a textbook chapter. Structure:

```
# {Topic} — Comprehensive Lecture

**Course:** Agentic AI in Software Delivery
**Module:** Part 1 or Part 2 — [name]
**Section:** [SDLC phase]
**Classification:** Required / Optional
**Primary Audience:** [roles]
**Format:** Slide Deck + Recorded Video

---

## Introduction: Why This Lecture Matters
[2–3 paragraphs. Make the case for why this topic is important, what pain it solves, and how AI changes the story.]

---

## Part 1 Tool Recap: How the Agentic AI Toolkit Maps to [Topic]
[Table mapping each Part 1 tool (AI Agents, Orchestrator/Subagent, MCP Tools, Skills, Planning Mode, Workspaces/Projects) to a concrete application in this topic. Follow this with 1–2 paragraphs per tool, written in full prose, explaining the application in detail.]

---

## Repository Blueprint: Claude + VS Code Copilot IaC Ecosystem
[Explain how `CLAUDE.md`, `.claude/agents/terraform.md`, `.claude/rules/terraform.md`, and `.claude/skills/terraform-checker/*` fit together. Include clear ownership boundaries between standards, orchestration, and validation.]

---

## End-to-End Workflow: Requirements → Generate → Validate → (Optional) Plan
[Walk through the exact workflow used in this repository, including requirement gathering, file generation, checker invocation, severity-based remediation, and optional `terraform plan`.]

---

## [Main section 1 — from content guidance or spec]
[Detailed prose. Include: what AI does here, which tools are used, concrete workflow steps, named tools/products, practical examples.]

---

## [Main section 2]
...

## [Main section N]
...

---

## Limitations and Risks
[What AI cannot do well in this area. Common failure modes. Where human judgment is still essential.]

---

## Practical Demo Walkthrough
[Include a concrete walkthrough based on this repository's files and commands. Show what to open, what to run, what outputs to expect, and where approval checkpoints exist.]

---

## Hands-On Exercise
[A concrete, step-by-step exercise the participant can complete during or after the lecture. Should use tools from Part 1 and apply them to the topic.]

---

## Key Takeaways
[5–7 bullet points. Concrete, specific, not generic.]
```

Requirements:
- No generic filler. Every paragraph must contain specific tool names, workflow steps, or concrete examples.
- Minimum 8 main sections beyond intro and toolkit recap.
- Length: comprehensive enough to be a standalone reference. Aim for depth over brevity.
- Must explicitly reference this repository's Claude/Copilot IaC ecosystem and files.
- Must describe validation/reporting expectations (severity and file/line references) and the optional-plan rule.

---

### Step 5 — Generate Artifact 2: Slide Deck Outline (`slides-outline.md`)

This document defines what goes on each slide. It is used by the presenter to build the actual deck. Structure:

```
# {Topic} — Slide Deck Outline

---

## Slide 1: [Slide Title]
**Type:** [Title / Section divider / Content / Demo / Exercise / Summary]
**What to present:**
- [Bullet 1 — specific content point, not a vague instruction]
- [Bullet 2]
- [Visual suggestion: diagram / screenshot / table / live demo]

---

## Slide 2: [Slide Title]
...
```

Requirements:
- Every slide must have a concrete title (not "Introduction" alone — e.g., "Why CI/CD Pipelines Are Still Painful Without AI")
- "What to present" bullets must be specific content points, not meta-instructions like "explain the concept"
- Include visual suggestions where a diagram or screenshot would strengthen the slide
- 20–35 slides total
- Follow the same section flow as `lecture.md`
- Include section divider slides between major sections
- Include explicit slides for repository anatomy and checker-driven validation workflow.

---

### Step 6 — Generate Artifact 3: Speaker Notes (`speaker-notes.md`)

One entry per slide, matching the slide titles from `slides-outline.md` exactly. Structure:

```
# {Topic} — Speaker Notes

---

## Slide 1: [Slide Title]
[3–6 sentences of spoken-word notes. Written as if the presenter is talking to the audience — not bullets, full prose. Include: what to say, what to emphasise, any live demo instructions, transitions to the next slide. Must be specific to the content of this slide — no generic phrases like "explain the importance of this topic".]

---

## Slide 2: [Slide Title]
...
```

Requirements:
- Every note must be specific to that slide's content — reference actual tool names, workflow steps, or examples from the lecture
- Write in natural spoken English, not formal academic prose
- Where a demo is suggested in the outline, the notes should describe exactly what to show and what to narrate
- No note shorter than 3 sentences
- Slide titles in speaker notes must match `slides-outline.md` exactly.

---

### Step 7 — Write the files

Create the output folder and write all three files:
- `generated-lectures/{slug}/lecture.md`
- `generated-lectures/{slug}/slides-outline.md`
- `generated-lectures/{slug}/speaker-notes.md`

After writing, confirm to the user:
- The folder path
- The three files created
- A one-line summary of what each file contains
