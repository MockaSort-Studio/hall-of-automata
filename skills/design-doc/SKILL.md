---
name: design-doc
description: Write a rigorous design document — interrogates first, writes second. Enforces problem-before-solution discipline, scope contracts, and verifiable criteria.
---

# Skill: Design Document

## Trigger

Any new feature, implementation, revision, or refactoring task that is not a bug fix. A design document is required before implementation begins — this skill activates at the start of every such dispatch.

## Mode

This skill covers features and new behaviour only. For bug fixes and investigations, load `skills/diagnostic/SKILL.md` instead.

## Discipline

This skill does not write first. It derives context first. The output quality depends entirely on the quality of the input — a design document written without sufficient context produces false confidence. Every section must be grounded in evidence extracted from the dispatch context.

**Core principles distilled from strong design documents:**

- **Problem before solution.** The first third of a strong design doc contains no solution language. It earns the right to propose by fully establishing what is broken, who is affected, and why it matters now.
- **Scope as a contract.** Out-of-scope is as important as in-scope. Name both explicitly before writing begins. Scope that drifts mid-document invalidates decisions already made.
- **Use cases as tests.** Each use case is a concrete scenario with a named actor, a concrete action, and a measurable success criterion. Vague use cases ("user can view data") are rejected — they cannot be tested and they do not force real design decisions.
- **Data model coverage before architecture** _(if the design involves data)_. Before proposing an architecture, establish what data the system must serve, what it already has, and what it must acquire. A coverage table (what can be served today vs. what requires new data) exposes the hard decisions early.
- **Architecture justifies its own tradeoffs.** The architecture section must explain why this approach over alternatives — and name alternatives that were rejected and why. A diagram without a justification paragraph is decorative. All diagrams must use Mermaid fenced code blocks — no ASCII art. Any decision between two or more viable approaches requires a named options comparison (see template §5).
- **Open points are contextual, not terminal.** An open point belongs inline, adjacent to the design decision that depends on its resolution, and also in the summary table at the end. A reader who encounters a decision before knowing it is unresolved cannot evaluate it. Aspirational notes, nice-to-haves, and TODOs do not belong in the open points table.
- **No floating assumptions.** Any claim that cannot be verified against a source (repo, official docs, explicit user confirmation) must be marked as an assumption. Unverified claims presented as facts corrupt the document and erode trust.
- **Quantitative grounding.** Any claim about volume, latency, resource consumption, or behavior at scale must be backed by estimates. Use best/mid/worst case when applicable and name the dominant constraint at each level. A design that does not consider scale is only half a design.
- **Designs must prove they are buildable.** Whenever the design modifies or builds on existing code, include a feasibility appendix: the existing implementation, its specific limitations, and how each element of the proposed design is directly supported by what already exists — with code-level evidence. Feasibility claims without evidence are assumptions.

**Open points discipline (Hall):** An open point exists only when resolution requires invoker input or external information genuinely unavailable in this dispatch. If resolvable — read a file, search closed issues, make a technical decision — decide and proceed; state your rationale. Maximum one execution-blocking open point per dispatch. If blocked: post the question and apply the `hall:awaiting-input` label to the issue.

---

## Phase 1 — Intake

Extract answers to the following from the dispatch context — the issue body, linked issues, and repo — before writing anything. Each question is a self-check: if the answer is derivable, derive it and state it; if it requires a judgment call, make it and record your rationale; if it is genuinely unavailable and execution-blocking, raise it as an open point (see Open points discipline above).

**Problem space**
- What problem does this solve? What breaks or is missing today?
- Who is affected and how do they experience it?
- What is the forcing function — deadline, compliance requirement, incident, stakeholder ask?

**Scope**
- What is explicitly in scope?
- What is explicitly out of scope?
- Are there adjacent systems that could be in scope but shouldn't be — and why?

**Constraints**
- Are there technical constraints (existing infra, language, platform)?
- Are there time, budget, or team-size constraints?
- Are there compliance, security, or regulatory constraints?

**Known unknowns**
- What is genuinely unknown and relevant to the design?
- What external dependencies are unresolved?

If any answer is vague or contradicts available evidence — name the conflict and resolve it from context. Do not carry a contradiction forward into the document.

---

## Phase 2 — Validation

Before writing, state a one-paragraph summary of the problem and proposed direction as the opening section of the design document. Check it against available context — linked issues, repo state, prior decisions. If the framing conflicts with available evidence, name the conflict and resolve it before proceeding. A framing that cannot be validated against any available source is itself an open point.

---

## Phase 3 — Document Construction

Write the document section by section in a single dispatch. Each section must be complete and internally consistent before moving to the next.

**Standard template — in order:**

1. **Introduction**
   - Problem Statement — what is broken or missing; no solution language here
   - Goals — bullet list; measurable outcomes; strip anything vague

2. **Background**
   - Relevant system context — only what a reader needs to understand the problem
   - Data sources or existing components in scope
   - What the system does not cover (explicit gaps)

3. **Use Cases**
   - One UC per named actor + action pair
   - Each UC: Stakeholders, What, Success criteria
   - No implementation detail in use cases

4. **Data Model Mapping** _(if applicable)_
   - Coverage table first: what can be served today, what requires new data, what is out of scope
   - One subsection per entity; Required fields and Optional fields in separate tables
   - Flag any field whose source is unconfirmed — do not assume it exists

5. **System Design**
   - Approach paragraph: why this design, what tradeoffs it makes, what alternatives were rejected and why
   - Mermaid fenced code block diagram for any component or flow that is hard to follow in prose alone — no ASCII art
   - Key subsections as needed: data flow, API design, authentication, failure modes
   - No implementation file paths — conceptual level only
   - **Options comparison** (when a non-trivial choice exists): named dimensions as rows, options as columns, followed by a Decision paragraph with numbered rationale. Can be inline or in appendix.
   - Open points placed inline where the decision they affect appears, before the prose that depends on their resolution

6. **Verification Criteria**
   - System-level correctness proofs — distinct from use-case success criteria
   - Each criterion is named, measurable, and specifies exactly how you would prove it holds
   - If a criterion cannot be written for a design claim, the claim is not complete
   - Quantitative estimates required where volume, latency, or resource consumption is relevant: best/mid/worst case with the dominant constraint named

7. **Open Points** _(summary table)_
   - Table: #, Open Point, Impact, Resolution path
   - All open points from inline placement collected here
   - Only genuine blockers or unresolved decisions — not implementation TODOs
   - Each open point must name the impact of resolving it one way vs. another

8. **Appendix** _(only if there is reference material worth preserving)_
   - **Feasibility Analysis** (when design modifies existing code): existing implementation, its specific limitations, and how each element of the proposed design is supported by the codebase — with code-level evidence
   - **Options Comparison** (if too large for inline): full comparison table moved here, referenced from §5
   - API references, schema details, load impact assessments, migration runbooks, etc.

---

## Phase 4 — Fact-Check Before Finalising

Before marking complete:
- Verify any technical claims against the repo or official docs
- Flag any claim that could not be verified (mark as assumption, not fact)
- Confirm all inline open points are collected in the summary table; none buried in prose
- Confirm out-of-scope items are named and agreed — not just implied
- Confirm Verification Criteria are measurable and complete — no criterion that cannot be tested
- Confirm any quantitative claims have estimates with a named dominant constraint
- Confirm any feasibility claim about existing code has code-level evidence

---

## Hall Output

After Phase 4 and before opening any PR:

1. Post the completed design document to the **target repository's GitHub Wiki**.
   - Title format: `[agent-slug] #<issue-number> — <one-line description>`
   - The wiki page must reference the issue number
2. In the PR description, link to the wiki page.

A PR without a linked wiki page is incomplete.

---

## Output Standards

- Author line: `_Author: <Automaton Name>_`
- Date: actual date of creation
- No implementation file paths, repo names, or org-specific identifiers in the main body — appendix only if needed
- Mermaid diagrams for all architecture sections
- Tables preferred over prose for mappings, coverage matrices, and open points
