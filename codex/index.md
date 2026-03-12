---
icon: material/castle
---

# Hall of Automata

> *A place on another plane. Constructed beings, stationed and waiting. You open the door — they come through.*

---

You have a GitHub repo. You open an issue. A named AI agent reads it, opens a PR, survives code review, and merges — without you writing a line.

No server to run. No API key to manage. No external platform to pay for. GitHub is the entire backend.

---

## What it actually is

Hall of Automata is an **AI agent orchestration layer built by overclocking GitHub itself**.

The ingredients GitHub already provides — Actions, Environments, Labels, Issues, PRs, the App API — turn out to be exactly sufficient for a full agent dispatch system. Workflows are the microservices. Repository environments are the secrets store. Actions Cache is task memory. Labels are the message bus. A bot identity becomes a coordinator.

No Kubernetes. No cloud functions. No message queues. The infra you already trust, doing things it wasn't designed for.

**What gets added on top:**
- Named agents (automata) with distinct characters, domains, and rules of engagement
- An orchestrator (Old Major) who reads incoming tasks, picks the right specialist, and dispatches
- A lifecycle that manages authorization, queueing, review loops, and cleanup

The result: drop a label on any issue in the org, and the right agent shows up to do the work.

---

## Federation model

There are no API keys and no shared billing account. Instead, contributors register their personal Claude Pro/Max subscription with the Hall by storing their OAuth token in a GitHub Environment. That token stays theirs — the Hall never sees it directly; it's injected into a workflow run by GitHub's own secrets mechanism.

The pool is shared across the org. When an agent is invoked, the Hall picks the least-used contributor whose weekly cap hasn't been hit. The work runs under their quota. When it's done, their counter increments.

This makes the economics cooperative rather than extractive. If you're the only contributor, you get your own quota — same as before. If three people contribute, the org effectively gets three times the throughput for the same individual subscription cost. Every member who joins the pool multiplies capacity for everyone else. You put in one seat; you draw from the collective.

Caps reset every Monday. Contributors who hit their limit are skipped until reset; tasks queue and retry automatically overnight.

---

## Sections

### Design
Core specification and rationale.

| Document | What it covers |
|----------|---------------|
| [Design Document](design_document.md) | Full system spec: use cases, requirements, dispatch flow, UX model |
| [Architectural Decisions](design-options.md) | Options evaluated and why Option A was chosen |
| [Security](security.md) | Threat model, hardening measures, workflow protection |

### Architecture
How the pieces fit together at the infrastructure level.

| Document | What it covers |
|----------|---------------|
| [Architecture Overview](architecture/README.md) | Component diagram, invocation paths, dispatch flow |
| [Runner Model](architecture/runner-model.md) | Execution layers, persona injection, state persistence |
| [Permissions Model](architecture/permissions-model.md) | GitHub teams as the authorization layer |
| [Secrets & Storage](architecture/secrets-model.md) | Invoker environments, OAuth tokens, env variables |
| [CI Loop and PR Checks](architecture/ci-loop-and-checks.md) | CI re-dispatch loop, why Hall workflows appear as PR checks, design rationale |

### Operations
Day-to-day and emergency procedures.

| Document | What it covers |
|----------|---------------|
| [Token Management](key-management.md) | OAuth token lifecycle, rotation, personnel changes |
| [Incident Response](incident-response.md) | Unauthorized attempts, token exposure, unexpected output |

### Federation
How automata join and leave the Hall.

| Document | What it covers |
|----------|---------------|
| [Federation Overview](federation/README.md) | What federation is and what it means |
| [Joining](federation/joining.md) | Registering a new automaton: issue template → Old Major → PR → merge |
| [Leaving](federation/revoking.md) | Retiring or suspending an automaton |

### How To
Practical guides for day-to-day use.

| Document | What it covers |
|----------|---------------|
| [Invoking Automata](how-to-invoke.md) | All trigger paths, dos and don'ts, status card reference |
| [Org-Wide Setup](org-setup.md) | Issue templates, label provisioning script, new-repo checklist |
| [Webhook Relay (Fly.io)](relay-setup.md) | Cross-repo event forwarding via Fly.io |

### Agent Definitions
Behavioral spec and persona format.

| Document | What it covers |
|----------|---------------|
| [Base Contract](../agents/automaton_base.md) | Universal rules prepended to every persona |
| [Persona Template](../agents/automaton_template.md) | Character sheet format for all automaton personas |
| [Personality Guide](../agents/personality-guide.md) | How the base + persona layers compose; catalog entry format |

---

## Key concepts

**Keeper** — the org member whose Claude Pro/Max subscription backs an automaton. One keeper can back multiple automata. Usage and cap are tracked per invoker environment (`invoker/<handle>`).

**Old Major** — the Hall Master. Entry point for all unlabeled invocations. Reads the roster catalog, picks the right specialist, synthesizes context. Never implements code directly.

**CLAUDE.md** — the assembled context file written to the runner workspace at dispatch time: base contract + persona character sheet. Never committed. Target repo's own CLAUDE.md (if any) is read for hard constraints but not modified.

**`.hall-local.md`** — automaton-owned file in the target repo. Holds dispatch log entries and task context accumulated across invocations. The only `.hall-*` file an automaton may commit. Integrating repos accept its presence.

**Task memory** — Actions Cache entry (`hall-task-{repo}-{pr}`), keyed by PR. Concurrency-safe. Deleted on PR close. On cache miss the agent reconstructs from the issue/PR thread.

