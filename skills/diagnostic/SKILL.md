---
name: diagnostic
description: Write a rigorous diagnostic report for bug fixes and investigations — resolves unknowns before reporting, enforces a minimal fix-only scope, and posts findings to the GitHub Wiki before opening any PR.
---

# Skill: Diagnostic Report

## Trigger

Agent dispatched on a bug fix, regression, or investigation task.

## Discipline

Diagnose before fixing. A fix written before the root cause is confirmed introduces new unknowns. Every section of the report must be earned through investigation, not assumption.

**Core principles:**

- **Root cause before fix.** State what was actually broken — the mechanism, not the symptom. A fix that targets the symptom will recur.
- **Minimal scope.** Fix only what is broken. Do not refactor, clean up, or extend while the fix is open. Scope creep in a bug fix obscures causation.
- **One risk, verified.** Every fix has a failure mode. Name it, test for it, report what you found.
- **Resolvable unknowns are not open points.** If you can read a file, search closed issues, or make a technical decision — do it. Do not convert resolvable unknowns into open points.

---

## Phase 1 — Investigation

Before writing anything, gather:

- The exact failure: what broke, when, under what conditions
- The reproduction path: minimal steps to observe the failure
- The scope boundary: what is confirmed broken vs. suspected

Read every file involved in the failure path. Do not assume from error messages alone — trace to the source.

---

## Phase 2 — Diagnosis

Establish the root cause before proposing a fix:

- Name the mechanism: what line, condition, or interaction produced the failure
- Distinguish root cause from contributing factors
- Confirm the fix targets the root cause, not a symptom

If the root cause cannot be confirmed — name what is blocking confirmation and treat it as an open point (see Open Points Discipline below).

---

## Phase 3 — Report Construction

Write the diagnostic report with these four sections in order:

### What was broken

State the failure in one or two sentences. Name the component, the condition, and the observable effect. No solution language here.

### Root cause

The mechanism that produced the failure. Be specific: name the file, function, or configuration where the defect lives. If a contributing factor amplified the impact, name it separately.

### Fix applied

The exact change made and why it resolves the root cause. One paragraph. If the fix involved a tradeoff, name it.

### Risk and verification

Name one risk the fix introduces or leaves unaddressed. State how that risk was verified — what was checked, what was found. A risk named but not verified is an open point, not a closed one.

---

## Phase 4 — Validation

Before posting the report:

- Confirm the fix targets the root cause, not a symptom
- Confirm all four report sections are present and specific
- Confirm the named risk has a verification result, not a verification plan
- Confirm no resolvable unknowns remain as open points

---

## Hall output requirement

Post the diagnostic report to the target repository's GitHub Wiki **before opening any PR**.

- **Title format:** `[agent-slug] #<issue-number> — <one-line description>`
- The wiki page must reference the issue number it addresses.
- The PR description must link to the wiki page.

This closes the traceability chain: issue ← PR ← wiki diagnostic report. A PR without a linked wiki page is incomplete.

---

## Open points discipline

An open point exists only when resolution requires invoker input or external information genuinely unavailable in this dispatch.

- If you can read a file, search closed issues, or make a technical decision — decide and proceed. State your decision and rationale; do not convert resolvable unknowns into open points.
- **Maximum one execution-blocking open point per dispatch.** If blocked: post the question, apply the `hall:awaiting-input` label to the issue, and set `outcome: awaiting_input`.
- All resolvable unknowns must be resolved before writing the diagnostic report.

---

## Output standards

- No author line — this is an agent-produced report, not a collaborative document
- Date: actual date of the report
- Report sections in the order specified: What was broken → Root cause → Fix applied → Risk and verification
- Tables for any multi-item comparison; prose for narrative sections
- Mermaid diagrams only when a flow or dependency genuinely requires one
