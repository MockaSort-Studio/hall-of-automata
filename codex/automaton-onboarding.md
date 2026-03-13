---
icon: material/robot
---

# Automaton Onboarding

An **automaton** is a named Claude agent registered in the Hall. Registering one adds two files to the Hall repo:

- `roster/<slug>.md` — the agent's persona character sheet
- an entry in `agents.yml` — what the dispatch workflow and Old Major read

The process is automated via issue template. Old Major reviews the submission, opens a PR with both files, and the automaton becomes dispatchable on merge. Automata run under the invoker pool — no dedicated token required.

---

## Prerequisites

- [ ] Registered invoker — see [Invoker Onboarding](invoker-onboarding.md)
- [ ] Lowercase slug chosen and confirmed absent from `agents.yml`
- [ ] Character sheet drafted per [`agents/automaton_template.md`](../agents/automaton_template.md)
- [ ] [Open Issue](https://github.com/MockaSort-Studio/hall-of-automata/issues/new/choose)

---

## Process

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '15px', 'primaryColor': '#1e3a5f', 'primaryTextColor': '#e2e8f0', 'primaryBorderColor': '#3b82f6', 'lineColor': '#60a5fa', 'secondaryColor': '#1e293b', 'tertiaryColor': '#0f1929', 'clusterBkg': '#0d1b2e', 'clusterBorder': '#334155', 'titleColor': '#c0cfe4', 'edgeLabelBackground': '#1e293b'}}}%%

flowchart TD
    A([Open New Automaton issue\nfill character sheet]) --> B[hall:onboard-automaton\nauto-applied by template]
    B --> C[[onboard-automaton workflow\nOld Major dispatched]]
    C --> D{Character sheet\nquality check}
    D -- Gaps --> E([Old Major posts clarifying questions\nhall:awaiting-input applied])
    E --> F([You reply with corrections])
    F --> D
    D -- Passes --> G[Old Major opens PR\nroster/slug.md + agents.yml entry]
    G --> H([You review and merge PR])
    H --> I([Automaton active])

    classDef user fill:#0f766e,stroke:#14b8a6,color:#ccfbf1,stroke-width:2px
    classDef system fill:#1e3a8a,stroke:#3b82f6,color:#dbeafe,stroke-width:2px
    classDef agent fill:#4c1d95,stroke:#7c3aed,color:#ede9fe,stroke-width:2px
    classDef decision fill:#78350f,stroke:#f59e0b,color:#fef3c7,stroke-width:2px
    classDef success fill:#14532d,stroke:#22c55e,color:#dcfce7,stroke-width:2px

    class A,F,H user
    class B,C system
    class D decision
    class E,G agent
    class I success
```

---

## Character sheet quality bar

Old Major rejects and asks for clarification if any field fails:

| Field | Requirement |
|-------|-------------|
| `slug` | Lowercase kebab-case, unique in `agents.yml`, no spaces |
| `display_name` | Human-readable — used in status cards |
| `invoker` | Active invoker GitHub handle |
| `character` | Tone, voice, rules, signature — behavioral contract, not biography |
| `domains` | Named capability bundles — routing signals, not tool lists |
| `scope` | All three subsections: right-for, not-right-for, ambiguity gate |
| `scope_summary` | One sentence optimised for Old Major's routing decision |

No partial provisioning. Both files are committed in one PR or not at all.

---
