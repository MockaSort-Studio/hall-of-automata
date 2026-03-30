# Hall of Automata

> *A place on another plane. Constructed beings, stationed and waiting. You open the door — they come through.*

---

You have a GitHub repo. You open an issue. A named AI agent reads it, opens a PR, survives code review, and merges — without you writing a line.

No server to run. No API key to manage. No external platform to pay for. GitHub is the entire backend.

---

## What it is

Hall of Automata is an AI agent orchestration layer built on GitHub Actions. The primitives GitHub already provides — Actions, Environments, Labels, Issues, PRs, the App API — are exactly sufficient for a full agent dispatch system. Workflows are the runtime. Environments are the secrets store. Labels are the message bus.

**What the Hall adds:**
- Named agents (automata) with distinct characters, domains, and rules of engagement
- An orchestrator (Old Major) who reads incoming tasks, picks the right specialist, and dispatches
- A lifecycle that handles authorization, queueing, review loops, and cleanup

Drop a label on any issue in the org, and the right agent shows up to do the work.

---

## Invoker model

There are no shared API keys and no billing account. Contributors register their personal Claude Pro/Max subscription as an **invoker** by storing their OAuth token in a GitHub Environment. The token stays theirs — GitHub's own secrets mechanism injects it at runtime.

The pool is shared across the org. When an agent is dispatched, the Hall picks the least-used invoker whose weekly cap hasn't been hit. Caps reset every Monday. Tasks queue and retry automatically if all invokers are at capacity.

---

## Agents

| Agent | Role | Invoke with |
|-------|------|-------------|
| 🦉 **Old Major** | Hall Master — triage, route, onboard | `hall:dispatch-automaton` |
| 🤘 **mergio** | CI/CD architect & pipeline enforcer | `hall:mergio` |

Specialists are added through a structured onboarding process. Old Major reviews each proposal and provisions the persona.

---

## How to invoke

**Let Old Major decide:** Apply `hall:dispatch-automaton` to any issue. Old Major reads the task, picks the right specialist, and hands it off.

**Direct dispatch:** Apply `hall:<agent>` to skip triage.

**PR review:** Comment `@hall-of-automata` on a review. The bound agent picks up the feedback and iterates.

**Cross-repo:** Works on any repo in the org via the Hall relay. The agent works in the target repo; lifecycle is managed from this Hall.

---

## Repository layout

| Path | Contents |
|------|----------|
| [`agents/`](agents/) | Base behavioral contract all automata share |
| [`roster/`](roster/) | Persona files for each active automaton |
| [`actions/`](actions/) | Composite actions (authorize, dispatch, memory, cleanup…) |
| [`scripts/`](scripts/) | JS/bash helpers called by workflows |
| [`.github/workflows/`](.github/workflows/) | Dispatch, onboarding, CI loop, cleanup workflows |
| [`agents.yml`](agents.yml) | Agent registry |

Full documentation at [mockasort-studio.github.io/hall-codex](https://mockasort-studio.github.io/hall-codex/).

---

*MockaSort Studio · [github.com/MockaSort-Studio](https://github.com/MockaSort-Studio)*
