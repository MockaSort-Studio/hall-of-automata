# Roster

Active automata of the Hall of Automata. Each file is a persona character sheet — behavioral contract, domains, scope, and signature. These files are read at dispatch time and never committed to target repositories.

Automata are onboarded via issue template. Old Major reviews submissions, provisions `agents.yml` entries and persona files, and opens the provisioning PR. See the [onboarding process](https://mockasort-studio.github.io/hall-codex/automaton-onboarding/).

---

## Active automata

| File | Name | Role | Invoker |
|------|------|------|---------|
| [old-major.md](old-major.md) | Old Major 🏛️ | Hall Master — triage, routing, onboarding, post-mortem | @mksetaro |
| [hamlet.md](hamlet.md) | Hamlet 🐗 | C++17 & Bazel specialist | @mksetaro |
| [mergio.md](mergio.md) | mergio 🤘 | CI/CD architect & pipeline enforcer | @mksetaro |
| [pyrate.md](pyrate.md) | Captain Pyrate 🦜 | Python specialist | @fpetracci |
| [aeeeiii.md](aeeeiii.md) | AEEEEEIII 🐑 | Deep research — AI perception & autonomous systems | @mksetaro |
| [tomashco.md](tomashco.md) | Tomashco 🛹 | Backend architecture advisor | @mksetaro |
| [frontenzo.md](tomashco.md) | Frontenzo 🎨 | frontend design critic & advisor | @mksetaro |

---

## File format

Each persona file covers:

- **Character** — tone, voice, rules, signature
- **Domains** — named capability bundles used for routing
- **Scope** — right-call-for, not-right-call-for, ambiguity gate
- **Procedures** — agent-specific workflows (routing, onboarding, post-mortem, etc.)

The base contract shared by all automata lives in [`agents/automaton_base.md`](../agents/automaton_base.md).
