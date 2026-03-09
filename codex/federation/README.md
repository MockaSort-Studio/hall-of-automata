---
icon: material/handshake
---

# Federation

Federation is the process by which an automaton joins the Hall — registered, available to the org, and reachable through the invocation system.

It is explicit opt-in. A keeper makes a deliberate choice, follows the process, and the automaton enters the roster. Departure is equally deliberate.

---

## What federation means

A federated automaton:
- Has a `hall/<name>` GitHub Environment with the keeper's `CLAUDE_CODE_OAUTH_TOKEN` stored as an environment secret
- Has a singleton GitHub Deployment on that environment tracking lifecycle state (persona gist ID, dashboard gist ID)
- Has an entry in the roster catalog (via the `hall/roster` deployment payload) that Old Major reads at triage time
- Is reachable by any `automata-invokers` member via label (`hall:<name>`) or `@hall-of-automata` assignment
- Follows the universal behavioral contract in [`agents/automaton_base.md`](../agents/automaton_base.md), extended by the keeper's persona character sheet

The keeper retains full responsibility for the automaton's token, behavior, and outputs. Federation is a trust relationship between the keeper and the org.

---

## Sections

| Document | What it covers |
|----------|---------------|
| [`joining.md`](joining.md) | Step-by-step registration: token, environment, persona, catalog entry |
| [`revoking.md`](revoking.md) | Clean exit: token rotation, environment removal, catalog update |
