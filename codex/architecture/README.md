---
icon: material/map
---

# Architecture

The Hall of Automata runs on GitHub Actions backed by GitHub Deployments and Gists. No self-hosted runners. No external databases. All state lives in GitHub infrastructure.

---

## Overview

```mermaid
flowchart TB
    subgraph ORG["GitHub Organization"]
        subgraph ANYREPO["Any Repository"]
            EV["Issue / PR\nassigned or labeled"]
        end

        subgraph HALL["hall-of-automata repo"]
            WF["GitHub Actions\nWorkflows"]
            OM["roster/old-major.md\n(Old Major persona — repo exception)"]
        end

        subgraph ENVS["Hall Environments"]
            subgraph ROSTER["hall/roster"]
                RD["Deployment (singleton)\npayload: catalog JSON\n(all agents + gist refs)"]
            end
            subgraph AGENTENV["hall/\u003cagent\u003e"]
                AV["Variables:\nHALL_USAGE_COUNT\nHALL_WEEKLY_CAP"]
                AD["Deployment (singleton)\npayload:\npersona_gist_id\ndashboard_gist_id"]
                AS["Secret:\nCLAUDE_CODE_OAUTH_TOKEN"]
            end
        end

        subgraph GISTS["GitHub Gists (per agent)"]
            PG["persona.md\n(character sheet — HMI + dispatch source)"]
            DG["dashboard.md\n(metrics · audit log · task history — HMI)"]
        end

        CACHE[("Actions Cache\nhall-task-{repo}-{pr}\n(task working memory)")]
    end

    subgraph RELAY["Fly.io Webhook Relay"]
        RE["Validates webhook signature\nForwards to hall workflow_dispatch"]
    end

    APP["Hall of Automata\nGitHub App"]

    EV -->|webhook| APP
    APP --> RE
    RE -->|workflow_dispatch| WF
    WF --- OM
    WF -->|read catalog| RD
    WF -->|read/write lifecycle| AD
    WF -->|read cap & usage| AV
    WF -->|read OAuth token| AS
    WF -->|fetch persona| PG
    WF -->|update dashboard| DG
    WF -->|task memory| CACHE
```

---

## Invocation paths

**Labeled path** — a `hall:<agent>` label is applied to an issue or PR. The named agent is dispatched directly. No Old Major triage step.

**Assignment path** — a issue or PR is assigned to `@hall-of-automata` without specifying an agent. Old Major runs first: reads the roster catalog from the `hall/roster` deployment, analyzes the task, selects the most capable available agent, synthesizes the task context, and dispatches the specialist. If confidence is insufficient, Old Major posts a clarifying question and enters the awaiting-input state.

---

## Dispatch flow

```
Event
  ├─ labeled      → authorize → fetch persona (gist) → dispatch specialist
  └─ assigned     → authorize → dispatch Old Major
                                    └─ triage → synthesize context
                                         └─ fetch persona (gist) → dispatch specialist
```

In both paths: persona is fetched from the agent's gist (via the `hall/<agent>` deployment payload), assembled with the base contract into CLAUDE.md, and the target repo's own CLAUDE.md (if any) is stashed as `.hall-local.md` for the agent to read.

---

## Sections

| Document | What it covers |
|----------|---------------|
| [`runner-model.md`](runner-model.md) | GitHub-hosted runners, persona injection, state persistence |
| [`permissions-model.md`](permissions-model.md) | GitHub teams as the authorization layer |
| [`secrets-model.md`](secrets-model.md) | Keeper environments, secrets, variables, and deployment payloads |

---

## Design rationale

The full record of options considered and why this architecture was chosen is in [`codex/design-options.md`](../codex/design-options.md).
