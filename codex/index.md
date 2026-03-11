---
icon: material/castle
---

# Hall of Automata — Documentation

This is the complete technical reference for the Hall of Automata. Start here.

---

## What is the Hall?

A federated AI agent orchestration layer built on GitHub Actions. Contributors donate their Claude Pro/Max subscription quota to a shared pool. The Hall dispatches named agents (automata) on demand, tracks keeper usage, enforces caps, and provides a unified `hall-of-automata[bot]` identity across the org.

No API keys. No external servers (yet — see [webhook relay](#roadmap)). No per-repo configuration. GitHub is the interface, the database, and the audit trail.

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
| [Secrets & Storage](architecture/secrets-model.md) | Keeper environments, OAuth tokens, deployment payloads, env variables |
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
| [Joining](federation/joining.md) | Registering a new automaton: issue template → Old Major → deployment |
| [Leaving](federation/revoking.md) | Retiring or suspending an automaton |

### How To
Practical guides for day-to-day use.

| Document | What it covers |
|----------|---------------|
| [Invoking Automata](how-to-invoke.md) | All trigger paths, dos and don'ts, status card reference |

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

**CLAUDE.md** — the assembled context file written to the runner workspace at dispatch time: base contract + persona character sheet. Never committed. Target repo's own CLAUDE.md (if any) is stashed as `.hall-local.md` for the agent to read.

**Task memory** — Actions Cache entry (`hall-task-{repo}-{pr}`), keyed by PR. Concurrency-safe. Deleted on PR close. On cache miss the agent reconstructs from the issue/PR thread.

---

## Roadmap

The immediate path before new features:

```
Smoke test (TEST_PLAN.md)
  → Phase 5: unauthorized hardening + cleanup fixes
  → Phase 5: keeper env variables (replace cache counter)
  → Phase 5: Old Major triage job + assignment trigger
  → Phase 5: deployment lifecycle actions
  → Webhook relay (Fly.io)
  → Full org test
```

Full breakdown in [`../TODO.md`](../TODO.md).
