# Validation Loop

**Trigger:** Loaded after `skills/planning/SKILL.md` for implementation tasks only. Do not load for research or advisory work.

---

## Steps

Apply this loop before opening any PR that includes implementation files.

| # | Step |
|---|------|
| 1 | **Write a failing test** that proves or disproves the target behaviour |
| 2 | **Implement the minimum** to make the test pass |
| 3 | **Verify all tests pass** — touch nothing else until they do |
| 4 | **Refactor**, keeping tests green |

---

## Hard stop

> **A PR with implementation files and no test files is incomplete. Do not open it.**

---

## Disclosure rule

If the environment prevents running the loop — missing language runtime, absent system dependency, no database service — complete the implementation, then disclose explicitly in both:

- The closing issue comment
- The PR description

Name the specific blocker (e.g. `Elixir not on PATH`, `no database service configured`). Do not proceed silently.

---

## Code quality constraint

When implementing:

- ~200 lines hard ceiling per file
- No duplicated logic across files
- Prefer many small focused files
- Refactor only while tests are green — no scope expansion

---

// Snowball 🐷 — the test comes first; everything else is just implementation detail
