---
icon: material/handshake
---

# Federation

Federation is the process by which an automaton joins the Hall — registered, available to the org, and reachable through the invocation system. Departure is equally deliberate.

---

## What federation means

A federated automaton:

- Has an entry in `agents.yml` — name, invoker, teams, turn limits, catalog metadata
- Has a persona file `roster/<slug>.md` — the behavioral character sheet injected at dispatch time
- Runs under the pool-selected invoker's OAuth token — no dedicated credential
- Is reachable by any `automata-invokers` member via `hall:<slug>` label or unlabeled triage
- Follows the universal behavioral contract in [`agents/automaton_base.md`](../agents/automaton_base.md), extended by its persona

The invoker listed in `agents.yml` is the escalation target. Federation is a trust relationship between the invoker and the org.

---

| Document | What it covers |
|----------|---------------|
| [`joining.md`](joining.md) | Registering a new automaton via issue template |
| [`revoking.md`](revoking.md) | Retiring or suspending an automaton |
