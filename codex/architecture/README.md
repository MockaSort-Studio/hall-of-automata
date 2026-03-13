---
icon: material/map
---

# Architecture

The Hall of Automata runs on GitHub Actions. No self-hosted runners. No external databases. All state lives in GitHub infrastructure — repository files, Environments, Actions Cache, and Artifacts.

---

## Overview

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '15px', 'primaryColor': '#1e3a5f', 'primaryTextColor': '#e2e8f0', 'primaryBorderColor': '#3b82f6', 'lineColor': '#60a5fa', 'secondaryColor': '#1e293b', 'tertiaryColor': '#0f1929', 'clusterBkg': '#0d1b2e', 'clusterBorder': '#334155', 'titleColor': '#c0cfe4', 'edgeLabelBackground': '#1e293b'}}}%%

graph LR
    subgraph HALL["hall-of-automata repo"]
        subgraph EVENTS["Triggering Events"]
            EV["Issue / PR\nlabeled · commented · reviewed"]
        end

        subgraph CODE["Repository Files"]
            WF["GitHub Actions\nWorkflows"]
            CATALOG["agents.yml\nlive agent catalog"]
            PERSONAS["roster/*.md\nagent personas"]
            BASE["automaton_base.md\nbase contract"]
        end

        subgraph INVOKERS["Invoker Pool — GitHub Environments"]
            INV1["invoker/handle\nOAuth token · usage · cap"]
            INV2["invoker/handle2\nOAuth token · usage · cap"]
        end

        CACHE[("Actions Cache\nhall-task-{repo}-{pr}\ntask working memory")]
        ARTS[("Actions Artifacts\nhall-log-{agent}-{issue}-{run}\naudit log per dispatch")]
    end

    CLAUDE["Anthropic\nInference"]

    EV -->|trigger| WF
    WF -->|pool-select least-used| INVOKERS
    WF -->|read catalog| CATALOG
    WF -->|inject persona| PERSONAS
    WF -->|base contract| BASE
    WF -->|task memory| CACHE
    WF -->|audit| ARTS
    INVOKERS -->|OAuth token| CLAUDE

    classDef event fill:#4c1d95,stroke:#7c3aed,color:#ede9fe,stroke-width:2px
    classDef workflow fill:#1e3a8a,stroke:#3b82f6,color:#dbeafe,stroke-width:2px
    classDef files fill:#1e293b,stroke:#475569,color:#e2e8f0
    classDef invoker fill:#14532d,stroke:#22c55e,color:#dcfce7,stroke-width:2px
    classDef storage fill:#0c1832,stroke:#1d4ed8,color:#bfdbfe
    classDef ai fill:#431407,stroke:#f97316,color:#ffedd5,stroke-width:2px

    class EV event
    class WF workflow
    class CATALOG,PERSONAS,BASE files
    class INV1,INV2 invoker
    class CACHE,ARTS storage
    class CLAUDE ai
```

---

## Invocation paths

**Labeled path** — a `hall:<agent>` label is applied to an issue or PR. The named agent is dispatched directly.

**Comment path** — `@hall-of-automata[bot] <agent>` is posted as a comment. The named agent is dispatched directly.

**Awaiting-input path** — an issue has `hall:awaiting-input` and `hall:<agent>` labels, and a human posts a new comment. The same agent is re-dispatched with the reply as additional context.

**PR review path** — a reviewer `@mention`s the bot in a pull request review. The agent is re-dispatched with the review feedback appended to its task memory.

**CI failure path** — a failing check suite on a `hall/*` branch triggers `hall-ci-loop.yml`. The agent is re-dispatched up to `max_retries` times before invoker escalation.

**Assignment path** *(planned)* — an issue is assigned to `@hall-of-automata` without specifying an agent. Old Major runs first to triage, select the right specialist, and synthesize context.

---

## Dispatch flow

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '15px', 'primaryColor': '#1e3a5f', 'primaryTextColor': '#e2e8f0', 'primaryBorderColor': '#3b82f6', 'lineColor': '#60a5fa', 'secondaryColor': '#1e293b', 'tertiaryColor': '#0f1929', 'clusterBkg': '#0d1b2e', 'clusterBorder': '#334155', 'titleColor': '#c0cfe4', 'edgeLabelBackground': '#0f1929'}}}%%

flowchart LR
    EV([Event])

    EV --> CURRENT["labeled · comment\nreview · CI failure"]
    EV --> PLANNED["assigned\n(planned)"]

    CURRENT --> D1["detect\npool-select invoker\nauthorize"]
    D1 --> D2["inject persona\ndispatch agent"]
    D2 --> D3["status card\ncounter · audit"]

    PLANNED --> P1["detect\ndispatch Old Major\ntriage"]
    P1 --> P2["select specialist\ninject persona"]
    P2 --> P3["dispatch\nspecialist"]

    classDef trigger fill:#4c1d95,stroke:#7c3aed,color:#ede9fe,stroke-width:2px
    classDef process fill:#1e3a8a,stroke:#3b82f6,color:#dbeafe,stroke-width:2px
    classDef planned fill:#1e293b,stroke:#475569,color:#94a3b8,stroke-dasharray:4 3

    class EV trigger
    class CURRENT,D1,D2,D3 process
    class PLANNED,P1,P2,P3 planned
```

In all current paths: the workflow checks out the Hall repo, reads `roster/{agent}.md` and `agents/automaton_base.md`, assembles them into `CLAUDE.md` in the workspace, and runs the Claude Code Action in a pool-selected `invoker/<handle>` environment. The CLAUDE.md is never committed — the runner is ephemeral.

---

## Sections

| Document | What it covers |
|----------|---------------|
| [`runner-model.md`](runner-model.md) | GitHub-hosted runners, persona injection, state persistence |
| [`permissions-model.md`](permissions-model.md) | GitHub teams as the authorization layer |
| [`secrets-model.md`](secrets-model.md) | Invoker pool environments, secrets, and variables |
| [`ci-loop-and-checks.md`](ci-loop-and-checks.md) | CI re-dispatch loop, PR checks side effects, and design rationale |

---

## Design rationale

The full record of options considered and why this architecture was chosen is in [`codex/design-options.md`](../design-options.md).
