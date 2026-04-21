# IaC with AI — Speaker Notes

---

## Slide 1: IaC with AI in Agentic Software Delivery
In this lecture, we are moving from tool familiarity to operational delivery. You already know agents and skills from Part 1, and now we will apply them to infrastructure work where mistakes are expensive. The goal is to show how a repository-level workflow turns AI into a reliable teammate instead of an unpredictable code generator.

---

## Slide 2: Why Teams Still Struggle with IaC Delivery
Most teams do not fail because they cannot write Terraform syntax; they fail because process quality is inconsistent. One engineer gets standards right, another skips validation, and a third runs plan at the wrong stage. AI can accelerate all three outcomes, so our focus is controlling the process, not just generating faster text.

---

## Slide 3: Learning Outcomes for This Session
By the end of this lecture, you should be able to run an end-to-end IaC workflow with clear checkpoints. You will know how to map repository files to operational responsibilities, and how to enforce severity-based remediation. You will also know when not to run plan, which is a surprisingly important control.

---

## Slide 4: Section Divider — Repository Blueprint
Now we switch from concept to implementation. We are going to use the actual repository files as the backbone of this lecture. Keep in mind that every workflow claim we make should be traceable to one of those files.

---

## Slide 5: Repository Anatomy for AI-Assisted IaC
Start with `CLAUDE.md` as the top-level flow contract, then move into agent, rules, and skill definitions. Point out that this structure separates behavior from policy and from execution checks. That separation is exactly what makes this model portable between Claude and Copilot environments.

---

## Slide 6: Separation of Concerns by Design
The key idea is that standards are not repeated in every prompt, they live in one rules file. The agent focuses on orchestration, while the checker skill focuses on validation and reporting. This design minimizes drift and makes reviews easier because everyone references the same policy source.

---

## Slide 7: Section Divider — Part 1 Toolkit Mapping
We now connect what you learned in Part 1 to this concrete IaC setup. Think of this as the translation layer from foundational concepts to production behavior. On the next slides, each tool maps to a specific operational role.

---

## Slide 8: Mapping Part 1 Tools to IaC Operations
Walk through the table row by row and avoid abstract language. For example, do not just say “skills are useful,” say that `terraform-checker` provides a repeatable validation contract with standardized findings output. Emphasize that this mapping is the reason the workflow is teachable and repeatable.

---

## Slide 9: AI Agents and Orchestration in Practice
The most important behavior in the agent file is requirement-first execution. Show that the agent is instructed to stop and ask clarifying questions instead of guessing critical infra values. That single guardrail prevents a large class of avoidable defects.

---

## Slide 10: MCP, Skills, and Persistent Context
MCP gives the assistant grounded context rather than forcing it to hallucinate environment details. The skill layer turns validation into a reusable procedure instead of ad-hoc command selection. Persistent workspace context then keeps decisions consistent across sessions and contributors.

---

## Slide 11: Section Divider — Canonical Delivery Workflow
From here on, we go stage by stage through the pipeline. The intent is to make each stage explicit enough that a team can copy it into its own repository. We are moving from architecture to execution discipline.

---

## Slide 12: Workflow Stage 1 — Gather Requirements
Call out the required fields and explain why each one matters operationally. Region and CIDRs are obvious, but backend and naming are where many real failures happen in teams. Mention that asking focused questions with recommended options speeds up decisions while preserving control.

---

## Slide 13: Workflow Stage 2 — Generate Terraform with Standards
When showing this slide, stress that generated files are not enough by themselves, they must align with policy. Required files create predictable module structure, and supporting files capture provider versions, backends, and local expressions. This is where AI output transitions from draft text to maintainable infrastructure code.

---

## Slide 14: Workflow Stage 3 — Validate via terraform-checker
Explain that the checker is the official quality gate in this repository model. It produces both detailed and concise outputs so engineers can debug deeply and triage quickly. Point out the importance of file and line references because they reduce remediation friction.

---

## Slide 15: Workflow Stage 4 — Optional terraform plan Policy
This is a policy slide, so be very explicit: plan is optional and approval-driven. The team should not run plan automatically for every iteration, especially in early drafting cycles. Also emphasize the one-session rule for long runs, because duplicate execution creates noisy and unreliable outcomes.

---

## Slide 16: Section Divider — Standards Deep Dive
Now we zoom into what standards actually enforce. This is where many teams realize they have conventions but not enforceable contracts. The next two slides show why codified standards improve both speed and reliability.

---

## Slide 17: Terraform Standards That Matter Most
Use a concrete before/after example to show improvement in readability and reviewability. Mention minimal-change behavior as a practical way to lower regression risk in shared repositories. Reinforce that version constraints are not optional hygiene, they are stability controls.

---

## Slide 18: Security and Tagging Baseline
Frame tagging as governance, not decoration. Required tags support ownership, environment traceability, and cost accountability, while `iac_origin` improves provenance when used correctly. Pair this with least-privilege and no-hardcoded-secrets as baseline security posture for generated IaC.

---

## Slide 19: Section Divider — Risk and Remediation
We now move from detection to decisions. This section helps teams avoid both extremes: ignoring findings or over-rotating on low-impact issues. The model is structured prioritization with explicit accountability.

---

## Slide 20: Severity-Driven Remediation Model
Critical means stop and fix before declaring completion. For high, medium, and low findings, explain how to decide based on release context and blast radius. If anything is deferred, show that the decision must be documented with clear rationale and ownership.

---

## Slide 21: Common Failure Modes in AI-Assisted IaC
Use this slide to normalize failure patterns and make them actionable. Missing requirements, policy drift, and async execution mistakes are common even in strong teams. The message is that controls in this repository are designed to prevent exactly these classes of failures.

---

## Slide 22: Section Divider — Live Demonstration
Tell the audience this demo is intentionally practical and lightweight. We are not proving cloud scale here; we are proving workflow correctness and decision quality. The value is repeatability, not flashy complexity.

---

## Slide 23: Demo Walkthrough — From Files to Workflow
Navigate files in order and narrate what each one governs. Then simulate a checker finding, choose a remediation path, and justify the decision using severity policy. Close by showing where plan would be requested and why you do not trigger it automatically.

---

## Slide 24: Hands-On Exercise — Build a Mini IaC Workflow
Explain that the exercise mirrors real team behavior: brief architecture input, AI generation, standards alignment, checker triage, and optional planning policy. Encourage participants to keep a small decision log for deferred non-critical findings. That habit builds production readiness much faster than code generation alone.

---

## Slide 25: Key Takeaways and Next Actions
Summarize the model in one sentence: governed AI workflow beats ad-hoc prompting for IaC delivery. Recommend that each participant adopt one standards file, one agent flow file, and one validation skill contract in their own repo this week. End by inviting them to run a pilot with a small infrastructure scope and measure rework reduction.
