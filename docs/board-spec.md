# GitHub Projects v2 Board Spec

Cross-invoker coordination layer for the Hall of Automata CLI. Implementation reference for the MCP server, `hall:init-board`, and Old Major's board read/write logic.

Companion document: [`board-spec-queries.md`](board-spec-queries.md) — all GraphQL templates.

---

## 1. Board Schema

### Status Column

Single-select field named `Status`. Canonical option set:

| Value | Semantic |
|---|---|
| Backlog | Identified; not yet scheduled |
| In Design | Advisor (Tomashco or equivalent) producing a spec |
| In Progress | Specialist actively implementing |
| In Review | PR open, awaiting merge |
| Blocked | Work stopped; blocker named in linked issue |
| Done | PR merged; work complete |

Status option node IDs are project-specific. Resolve them at init time via `GetProjectMeta` (see queries doc §2) and persist to `.hall-cache/session/board-meta.json`.

### Custom Fields

| Field | Type | Values / Notes |
|---|---|---|
| `Invoker` | text | GitHub login of the session owner |
| `Priority` | single-select | `critical`, `high`, `medium`, `low` |
| `Design Doc` | text | URL to spec PR, file, or external doc |
| `Risk` | single-select | `none`, `low`, `medium`, `high` |
| `Epic` | text | Short name grouping related items |
| `Specialist` | single-select | Hall specialist slug: `tomashco`, `snowball`, `mergio`, `indiana-docs` |

All six fields must be created at board init. `Specialist` single-select options are a fixed set; add new values when new specialists are registered in the Hall roster.

---

## 2. Label Taxonomy

### `type/*`

| Label | When to apply |
|---|---|
| `type/feature` | New user-facing capability |
| `type/bug` | Incorrect behaviour in existing functionality |
| `type/chore` | Maintenance, dependency updates, non-functional changes |
| `type/spike` | Time-boxed research; output is a spec or ADR, not code |

### `component/*`

Convention: `component/<slug>` where `<slug>` is defined per project. Examples: `component/mcp-server`, `component/cli`, `component/board-sync`. Register components in `.hall-cache/session/board-meta.json` under `"components"`.

### `priority/*`

| Label | Meaning |
|---|---|
| `priority/critical` | Blocks the next release or a dependent specialist |
| `priority/high` | Should land in the current planning cycle |
| `priority/medium` | Default; no urgency constraint |
| `priority/low` | Nice to have; deferred if quota is scarce |

### `hall/*`

Existing operational labels (unchanged):
- `hall:<specialist>` — dispatch target (e.g. `hall:tomashco`)
- `hall:blocked` — Old Major has flagged a blocker
- `hall:review` — awaiting human review

New labels added by this spec:

| Label | Purpose |
|---|---|
| `hall:board-sync` | Issue has a corresponding Projects v2 item |
| `hall:cross-invoker` | Item is referenced or commented on by a foreign invoker |

---

## 3. Invoker-Scoped Write Protocol

### Rules

1. **Own items only for field writes.** Old Major may call `UpdateField` only on items where `Invoker` field equals the current session's GitHub login.
2. **Comment on foreign items.** On items owned by other invokers, Old Major may call `AddComment` on the linked issue. No field mutations.
3. **Invoker resolved at session start.** Run `gh api user --jq '.login'`; cache result in `.hall-cache/session/config.json` under `"invoker"`.

### Cross-Invoker Comment Schema

Comments carrying structured cross-invoker data must embed the following block. The sentinel `hall-board-msg` is the extraction key — parsers scan comment bodies for a fenced block with this language tag.

~~~markdown
```hall-board-msg
{
  "version": "1.0",
  "from": "<invoker-github-login>",
  "type": "dependency|overlap|risk|info",
  "source_item": "<ProjectV2Item node ID of sender's item>",
  "target_item": "<ProjectV2Item node ID of addressee's item>",
  "body": "<human-readable message — one paragraph>",
  "metadata": {}
}
```
~~~

`type` semantics:

| Type | When to use |
|---|---|
| `dependency` | Sender's item cannot ship until target merges |
| `overlap` | Sender and target touch the same file or API surface |
| `risk` | Sender has identified a risk to target's approach |
| `info` | General cross-invoker notice; no action required |

Human-readable text must also appear outside the code fence so GitHub renders it usefully.

---

## 4. Lifecycle Integration

### When Old Major Reads the Board

| Trigger | Operation | Output |
|---|---|---|
| `hall:open` | Full board fetch (all pages) | `.hall-cache/session/board.json` + `board-context.md` |
| Plan creation | Re-read board from cache (no API call unless >5 min stale) | Dependency/overlap check before dispatch |
| Reconcile tick (watcher.sh) | Incremental fetch — items modified since last tick | Merge into `board.json`; regenerate `board-context.md` |

Staleness threshold: 5 minutes. If `board.json` mtime is older than 5 min, re-fetch before plan operations.

### When Old Major Writes the Board

| Event | Field writes | Comment |
|---|---|---|
| Plan created, task dispatched | `Status` → `In Progress`; `Specialist` → specialist slug | Post one-paragraph summary on linked issue |
| PR opened | `Status` → `In Review` | None |
| PR merged | `Status` → `Done` | None |
| Blocker detected | `Status` → `Blocked` | Post blocker description on linked issue |

### Cache Schema

**`.hall-cache/session/board.json`**

```json
{
  "fetched_at": "<ISO-8601 timestamp>",
  "project_id": "<node ID>",
  "items": [
    {
      "id": "<item node ID>",
      "issue_id": "<issue node ID>",
      "issue_number": 42,
      "title": "...",
      "state": "OPEN|CLOSED",
      "assignees": ["login"],
      "labels": ["hall:tomashco"],
      "fields": {
        "Status": "In Progress",
        "Invoker": "alice",
        "Priority": "high",
        "Design Doc": "https://...",
        "Risk": "low",
        "Epic": "cross-invoker-sync",
        "Specialist": "tomashco"
      }
    }
  ]
}
```

**`.hall-cache/session/board-context.md`**

Human-readable summary injected into session context. One table row per open item owned by the current invoker; a separate section for foreign items in `In Review` or `Blocked` state. Generated from `board.json`; regenerated on every board write.

---

## 5. Init Requirements

`hall:init-board` must:

1. Create the Projects v2 board in the target repo's owner org/account.
2. Create all six custom fields with correct types and option sets.
3. Create all labels in §2 that do not already exist.
4. Run `GetProjectMeta` and persist result to `.hall-cache/session/board-meta.json` (field IDs, option IDs, project node ID).
5. Write the project number to `.hall-cache/session/config.json` under `"board_project_number"`.

`board-meta.json` schema: `{ "project_id": "...", "fields": { "<field-name>": { "id": "...", "options": { "<option-name>": "<option-id>" } } } }`.

// Tomashco 🛹 — spec designed so the MCP server never has to hardcode an option ID
