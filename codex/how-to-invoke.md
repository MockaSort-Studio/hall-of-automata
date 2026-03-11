---
icon: material/play-circle
---

# How to Invoke an Automaton

This page explains every supported way to trigger an agent, what happens at each step, and what to avoid.

---

## Invocation model

The Hall is **label-driven**. Labels on issues and PRs are the canonical signal — they declare which agent owns that thread. Comments and reviews are only processed when a binding label is already present (or explicitly included).

There is no magic comment syntax. You cannot summon an agent by typing `@hall-of-automata do this` in a comment. Labels bind the thread; comments continue a bound thread.

---

## Use case 1 — Task issue (the standard path)

Use this when you want an automaton to do work: implement a feature, fix a bug, write a script, research a question.

```mermaid
flowchart TD
    A([Open issue from\n"Automaton Task" template]) -->|template auto-applies\nhall:dispatch-automaton| B
    B[[invoke.yml fires\nOld Major dispatched]] --> C
    C[Old Major reads issue,\npicks the right specialist\napplies hall:agent] --> D
    D[[invoke.yml fires again\nspecialist agent dispatched]] --> E
    E[Agent works,\nopens PR or replies] --> F([Status card updated\non your issue])
```

**Steps:**

1. Open a new issue using the **Automaton Task** template.
2. Fill in: what you want done, which repository, and which mode (`doing` / `advising` / `researching`).
3. Submit — the template auto-applies `hall:dispatch-automaton`.
4. Old Major is dispatched automatically. He reads the issue, selects the right agent, and applies `hall:<agent>` (e.g. `hall:hamlet`).
5. The specialist agent is dispatched. A status card appears on the issue tracking its progress.
6. The agent opens a PR when done (in `doing` mode), or replies directly on the issue (in `advising`/`researching` mode).

**Modes:**

| Mode | What the agent does | Thread outcome |
|------|---------------------|----------------|
| `doing` | Implements and opens a PR | Issue stays open until PR merged |
| `advising` | Analyses and posts a reply | Issue stays open — close it yourself when done |
| `researching` | Deep research, no code changes | Issue stays open — close it yourself when done |

---

## Use case 2 — Continuing a conversation (awaiting-input reply)

When an agent needs more context it posts a clarifying question and the issue is labeled `hall:awaiting-input`. Reply directly on the issue thread to re-dispatch the same agent.

**Steps:**

1. Read the agent's question in the status card or comment thread.
2. Reply with the requested information as a new comment on the issue.
3. The Hall automatically re-dispatches the bound agent (`hall:<agent>` label determines who).
4. `hall:awaiting-input` is stripped before the agent runs again.

> **You do not need to apply or remove any labels.** Just comment.

---

## Use case 3 — PR review re-dispatch

Use this when a PR opened by an agent needs correction after a code review.

**Steps:**

1. Open a **Pull Request Review** (not a plain comment) on the agent's PR.
2. Include `@hall-of-automata <agent>` in the review body — this is required.
3. Submit as **Comment** or **Request changes** — both trigger dispatch.

```
@hall-of-automata hamlet the test in src/foo_test.cpp is missing the edge case
for empty input. Please add coverage.
```

The agent is re-dispatched with your review feedback injected into its context alongside restored task memory.

---

## Use case 4 — Direct agent dispatch (power users)

If you know exactly which agent you want and want to skip Old Major, apply `hall:<agent>` directly to an issue instead of `hall:dispatch-automaton`.

| Label | Dispatched agent |
|-------|-----------------|
| `hall:dispatch-automaton` | Old Major (triage → routes to specialist) |
| `hall:hamlet` | Hamlet (C++ / build / devops) |
| `hall:old-major` | Old Major (direct) |

Apply the label yourself via the GitHub UI or `gh issue edit --add-label`.

---

## Status card

Every dispatch creates or updates a `<!-- hall-status -->` comment on the issue or PR. It shows the current lifecycle stage:

| Stage | Meaning |
|-------|---------|
| Assigning | Old Major is routing to the right agent |
| Dispatching | Specialist agent is starting |
| Working | Agent is actively running |
| PR opened | Agent opened a PR, link in card |
| Awaiting context | Agent posted a question, waiting for reply |
| Queued | All invoker quota exhausted, will retry |
| Failed | Something went wrong — check comments |
| Done | Response posted (advising/researching) or PR merged (doing) |

---

## Dos and Don'ts

### ✅ Do

- **Use the issue template.** It sets the right label and structure automatically.
- **Reply directly on the issue** when you see `hall:awaiting-input`. Just comment — no labels needed.
- **Use PR Reviews** (not plain PR comments) when you want to re-dispatch an agent on its PR.
- **Specify mode** in the issue template. `advising` and `researching` get closed automatically when done.
- **Leave labels alone.** Hall labels (`hall:*`) are the system's state machine. They are managed by the Hall.

### ❌ Don't

- **Don't type `@hall-of-automata` in a plain comment hoping to trigger dispatch.** This is not how invocation works. Use labels or PR reviews.
- **Don't manually remove `hall:<agent>` from an issue or PR.** This breaks re-dispatch — the agent won't be found on the next comment reply or review.
- **Don't remove `hall:awaiting-input` manually.** The Hall strips it automatically when re-dispatching. Removing it early breaks the reply path.
- **Don't apply `hall:dispatch-automaton` to a PR.** Task routing is for issues. Use PR reviews for PR-bound work.
- **Don't apply multiple `hall:<agent>` labels to the same issue.** Only one agent can own a thread; Old Major manages routing.
- **Don't close an issue while an agent is working** (stage = Working / Dispatching). The agent may still push commits and open a PR.
- **Don't comment on a PR to re-dispatch.** Plain PR comments are only processed in awaiting-input state. Use a PR Review instead.

---

## Quota and pool selection

Invokers each have a weekly dispatch cap (`HALL_WEEKLY_CAP`, measured in hours × 3 dispatches per hour). The Hall automatically picks the least-used invoker under cap. You never choose which invoker's token backs your dispatch.

If all invokers are at cap, the issue is labeled `hall:invoker-queued` and a comment explains the situation. The queue is not automatic — re-trigger manually after the weekly reset (Monday 00:00 UTC) or when a new invoker registers.

---

## Quick reference

| Scenario | Action |
|----------|--------|
| New task (any kind) | Open issue from **Automaton Task** template |
| Agent asked a question | Reply on the issue thread |
| Review agent's PR | Submit a **PR Review** (include `@hall-of-automata` in body) |
| Want a specific agent | Apply `hall:<agent>` label to the issue |
| Quota exhausted | Wait for Monday reset or ask an invoker to register |
| Something went wrong | Check the status card stage and workflow run link |
