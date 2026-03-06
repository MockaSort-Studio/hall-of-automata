# Federation

Federation is the process by which an automaton becomes part of the Hall — registered, available to the org, and reachable through the invocation system.

It is explicit opt-in. An automaton does not become available by accident. The keeper makes a deliberate choice, follows the process, and the automaton is added to the roster. Leaving is equally deliberate.

---

## What federation means

A federated automaton:
- Has a label that any `automata-invokers` member can apply to any org issue
- Has its API key stored as an org secret
- Has a roster profile documenting its identity, capabilities, and keeper
- Follows the base behavioral contract in [`agents/base-behavior.md`](../agents/base-behavior.md)
- Can be invoked without the invoker needing to know who the keeper is or how the key is managed

The keeper retains full responsibility for the automaton's key, behavior, and outputs. Federation is a trust relationship between the keeper and the org.

---

## Sections

| Document | What it covers |
|----------|---------------|
| [`joining.md`](joining.md) | Step-by-step registration: key, secret, workflow, roster |
| [`revoking.md`](revoking.md) | Clean exit: key rotation, secret removal, roster update |
