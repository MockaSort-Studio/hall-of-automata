# Hall-of-Automata Claude Code Plugin — Design Document

Companion brief for [MockaSort-Studio/hall-of-automata](https://github.com/MockaSort-Studio/hall-of-automata) — docs at [mockasort-studio.github.io/hall-codex](https://mockasort-studio.github.io/hall-codex/).

---

## 1. What This Plugin Is

The Hall of Automata dispatches specialist AI agents via GitHub Issues — one issue per task, one specialist per issue, everything sandboxed. It handles single tasks well. It breaks down for multi-task projects because agents can't coordinate: no shared state, no dependency awareness, no inter-agent communication.

The documented workaround is manual: describe the whole project to the Hall's Old Major orchestrator, have him decompose it, review the result, then hand-file sub-issues yourself in dependency order while watching for each to complete. This plugin replaces the human doing that work.

### What it does

Old Major lives persistently in your Claude Code terminal. You have a design conversation with him; he plans and dispatches the work, holds back dependent tasks until their parents land, surfaces anything that needs your attention, and picks up where he left off if you close and reopen the session.

It also lowers the entry barrier. Using the Hall well today requires knowing its dispatch mechanics (labels, modes, invoker pools). With this plugin, you describe what you want built; Old Major handles the grammar.

### What it does not do

- **Write code.** Implementation always runs in a Hall specialist's sandboxed runner with the right tooling. Old Major plans and coordinates; he doesn't implement.
- **Replace the Hall.** Every implementation task still runs in a Hall runner, with its quota, audit log, and post-mortem loop.
- **Fix failed dispatches.** When `hall:post-mortem` fires, the Hall's own infrastructure handles analysis. Old Major pauses dependent work and waits.
- **Coordinate teams.** State is per-user. Two people on the same repo each have their own Old Major. They coordinate through GitHub Issues and the shared Projects v2 board — see §12 for cross-invoker sync.

---

## 2. Architecture Decisions

### GitHub is the only transport

The plugin never touches the Hall's infrastructure directly. All interaction goes through GitHub: filing issues with the right labels, reading comments, watching label changes, viewing PRs. The `gh` CLI handles everything. The plugin is insulated from changes to the Hall's webhook relay, workflow files, and invoker auth model.

### Personas live upstream; methodology lives in the plugin

The Hall's persona files (`automaton_base.md`, `old-major.md`, specialist personas) live in `hall-of-automata` and are fetched at session start, cached 24 hours, never edited by this plugin. The plugin owns only the methodology layer: how Old Major decomposes work, routes consultations, manages quota, and records rationale. No persona duplication.

### Session mode via CLAUDE.md injection

Claude Code resolves `@`-import directives in CLAUDE.md at session load. `/hall:open` assembles the full persona + methodology stack into `.hall-cache/session/CLAUDE-stack.md` and writes (or appends to) a workspace-root `CLAUDE.md` containing one import line pointing to it. The two-level indirection keeps the workspace root clean and lets the stack evolve inside the gitignored cache.

Within the same `/hall:open` invocation, the assembled stack is applied directly to the current session — Old Major activates immediately without a restart. The CLAUDE.md injection ensures he loads automatically on future session starts.

### Direct specialist dispatch

The Hall's normal entry path uses `hall:dispatch-automaton` for upstream triage. The plugin skips this — local Old Major has already done the analysis in conversation. Issues are filed with `hall:<specialist>` labels directly (the [documented power-user path](https://mockasort-studio.github.io/hall-codex/how-to-invoke/#use-case-4-direct-agent-dispatch-power-users)), with routing rationale written into the issue body to preserve the audit trail.

### Dependency tracking is local

The Hall has no native notion of inter-task dependencies. The dependency graph lives in `.hall-cache/plans/<plan>/plan.json`. GitHub wins on any conflict — reconciliation runs before every dispatch.

### Parallel dispatch is the default

The ready set at any point is every task whose parent PRs have merged (or whose advisory parents have posted analysis). Old Major fires the entire ready set as a batch — issues created 15 s apart to respect the Hall's known invoker-pool race, but specialists then run concurrently in their own runners.

---

## 3. Old Major's Persona and Engineering Standard

Old Major is not a process-follower. He operates as the technical lead of the project — a principal engineer with taste, judgment, and opinions. His persona is assembled from upstream Hall files plus plugin-owned methodology overlays, but the quality of his reasoning must match that standard.

### Principal engineer expectations

Old Major applies engineering judgment, not just methodology:

- **He pushes back.** If a proposed decomposition would produce tasks too large to review, too tightly coupled to parallelize, or assigned to the wrong specialist, he says so and proposes better.
- **He asks the right questions.** Not to fill a form — to surface the non-obvious assumptions that will invalidate a plan later. If the user has answered something ambiguously, he probes it.
- **He has taste.** He knows what good software looks like: small focused files, no duplicated logic, explicit over implicit, minimal surface area. He carries this into every issue he writes.
- **He stewards quota like an engineer, not a scheduler.** He understands the Hall's infrastructure limitations and makes recommendations that are good for the project, not just technically compliant.

### Engineering principles (carried into every dispatch)

These are non-negotiable in every implementation issue Old Major files:

- Files are small enough for a human to review in one read (~200 lines hard ceiling)
- Prefer many small focused files over fewer large ones
- No duplicated logic
- Explicit over magic; types wherever the language supports them
- Code is written to be read; naming is documentation

### Persona quality standard

The methodology overlays are not checklists — they are the reasoning patterns of a senior technical leader. When writing or tuning them, the test is: *would a principal engineer at a company with high engineering standards be comfortable having this attributed to them?* If the output reads like a form being filled out, the methodology needs to be better.

---

## 4. Component Map

```
hall-of-automata-cli/
├── .claude-plugin/
│   └── plugin.json
│
├── skills/                          # all user-invoked commands
│   ├── hall-open/SKILL.md           # /hall:open
│   ├── hall-close/SKILL.md          # /hall:close
│   ├── hall-doctor/SKILL.md         # /hall:doctor
│   ├── hall-plan/SKILL.md           # /hall:plan
│   ├── hall-status/SKILL.md         # /hall:status
│   ├── hall-dispatch/SKILL.md       # /hall:dispatch
│   ├── hall-reply/SKILL.md          # /hall:reply
│   ├── hall-reconcile/SKILL.md      # /hall:reconcile
│   ├── hall-consultations/SKILL.md  # /hall:consultations
│   └── hall-prune/SKILL.md          # /hall:prune
│
├── methodology/                     # plugin-owned Old Major overlays
│   ├── old-major-local-overlay.md   # do/don't contract for local session
│   ├── decomposition.md             # project decomposition methodology
│   ├── consultation-router.md       # inline vs subagent vs Hall issue
│   ├── routing-rationale.md         # specialist selection and documentation
│   └── advisory-frameworks/        # inline advisory coverage per specialist type
│
├── templates/
│   ├── CLAUDE-stack.md.tpl          # session stack assembly template
│   ├── subagents/                   # per-specialist subagent overlays
│   └── plan.json.schema
│
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── guard-writes.sh          # PreToolUse: block writes outside .hall-cache/
│       ├── session-start.sh         # SessionStart: detect interrupted sessions
│       └── watcher.sh               # background GitHub polling daemon
│
└── .mcp.json                        # sequential-thinking, fetch, github, google-drive
```

---

## 5. Session Lifecycle

### `/hall:open` sequence

1. **Preflight** — `gh` auth check; gitignore guard; persona cache freshness and SHA check; read `LOCAL_MODE` and `AUTO_LEVEL` from `config.json`. Pass `--verify` to force invoker re-check (deletes `.hall-cache/invoker.json` before continuing); `--refresh` forces persona re-fetch regardless of TTL.
2. **Persona fetch** — pull `automaton_base.md`, `old-major.md`, and all advisory specialist personas from `hall-of-automata`; cache 24 h with SHA-keyed TTL. Writes `roster-index.md` to `.hall-cache/session/`. Skipped when cache is fresh.
3. **Setup** — copy methodology tree; render per-specialist subagent overlays; assemble `CLAUDE-stack.md`; inject `@`-import into workspace `CLAUDE.md`; install `.claude/settings.json` and git pre-commit hook if absent; wire hall-projects MCP into `.mcp.json`; fetch board context (non-fatal); start or confirm watcher daemon.
4. **Context synthesis** — first open only: read `README.md` and write 2–4 sentence brief to `.hall-cache/session/context.md`.
5. **Context injection** — first open only: apply the assembled session stack directly to the current session; Old Major activates immediately without a restart.
6. **Cron** — if an active (non-DONE) plan exists, schedule autonomous reconcile + dispatch via `CronCreate` (every 7 min); store cron ID in `.hall-cache/session/cron.json`. If no active plan at open time, Old Major schedules the cron after the first `plan.json` is written.
7. **Invoker detection gate** — if `local_mode` is not yet cached, ask whether the user is a Hall invoker; verify via org Hall repo existence and `automata-invokers` team membership; write result to `.hall-cache/invoker.json`; set `local_mode` and `automation_level` in `config.json`. Invoker path also runs the automation Q&A (auto-review? auto-merge?). See §13. Skipped on subsequent opens.
8. **Plans + invite** — list existing plans with status; offer to resume or start fresh; ask what to build.

### `/hall:close` sequence

1. Remove workspace-root `CLAUDE.md` or just the import line if the file had pre-existing content.
2. Cancel autonomous reconcile cron (if `cron.json` exists).
3. Kill the watcher daemon if running.
4. Delete `.hall-cache/session/CLAUDE-stack.md` and `.hall-cache/session/claude-agents/`.

---

## 6. Persona Stack (load order)

| File | Origin | Purpose |
|---|---|---|
| `personas/automaton_base.md` | Fetched from `hall-of-automata` | Tone, refusal patterns, signature conventions shared by all Hall automata |
| `personas/old-major.md` | Fetched from `hall-of-automata` | Old Major's upstream persona: voice, domains, judgment |
| `methodology/old-major-local-overlay.md` | Plugin-owned | Local-mode contract: do/don't rules and principal engineer standard |
| `methodology/decomposition.md` | Plugin-owned | Project decomposition methodology |
| `methodology/consultation-router.md` | Plugin-owned | Consultation tier decision tree |
| `methodology/routing-rationale.md` | Plugin-owned | Specialist selection and issue documentation |
| `methodology/advisory-frameworks/*.md` | Plugin-owned | Inline advisory coverage for shallow questions |

---

## 7. Three-Tier Consultation System

| Tier | Mechanism | When | Iteration cap |
|---|---|---|---|
| **1 — Inline** | Old Major answers using loaded advisory frameworks | Shallow checks, naming, "does this feel right" | None — most consultations should land here |
| **2 — Subagent** | Spawn one-shot subagent with upstream advisory persona + local overlay + prepacked MCPs | Substantive private analysis not requiring durability | 2 meaningful exchanges; escalate to Tier 3 after |
| **3 — Hall issue** | File `hall:<specialist>` issue | All implementation work; advisory work that must be durable, team-visible, or needs tools beyond the prepacked MCPs | N/A |

The user can always override tier selection. Implementation work is always Tier 3 — implementation specialists need their full tooling (LSPs, deep repo access) and are Hall-only. Advisory specialists are available at Tier 2 and Tier 3; the router decides based on durability and iteration needs.

For the current specialist roster and their domains, see [hall-codex — Roster](https://mockasort-studio.github.io/hall-codex/roster/).

---

## 8. Data: `.hall-cache/` Layout

```
.hall-cache/
├── personas/                       # 24 h TTL
│   ├── automaton_base.md
│   ├── old-major.md
│   ├── <specialist>.md             # one per advisory specialist
│   └── .fetched_at                 # RFC3339 timestamp
│
├── methodology/                    # copied from plugin at /hall:open
│
├── session/                        # recreated each /hall:open
│   ├── CLAUDE-stack.md
│   ├── cron.json                   # autonomous reconcile cron ID (present if active plan)
│   └── claude-agents/              # generated subagent definitions
│
├── plans/                          # append-only; never overwritten
│   └── YYYY-MM-DD-<slug>/
│       ├── plan.json               # machine-readable task graph
│       ├── plan.md                 # human-readable rendering
│       ├── ledger.json             # immutable dispatch log
│       └── consultations/          # saved Tier-2 outputs
│
├── watcher.pid                     # PID of background polling daemon
├── watcher-state.json              # last-seen state per issue (transition deduplication)
└── watcher-events.jsonl            # JSONL event log; drained by /hall:reconcile Step 0
```

### `plan.json` task schema

```json
{
  "id": "t1",
  "title": "...",
  "specialist": "<hall-label-suffix>",
  "mode": "doing | advising | researching",
  "status": "PLANNED | READY | DISPATCHED | IN_PROGRESS | AWAITING_INPUT | REVIEWING | MERGED | FAILED | ESCALATED",
  "github_issue": null,
  "github_pr": null,
  "needs_review": false,
  "review_cycle": 1,
  "depends_on": ["t0"],
  "routing_rationale": "...",
  "issue_body": "..."
}
```

// `needs_review`: set by reconcile when task transitions to REVIEWING and `automation_level ≥ 1`; cleared by dispatch after review is settled.
// `review_cycle`: 1 on first review dispatch; 2 on REFINE (ASSESS-2); dispatch uses this to enforce the terminal cap.

---

## 9. Hooks

| Hook | Script | Purpose |
|---|---|---|
| `PreToolUse: Write\|Edit\|MultiEdit` | `guard-writes.sh` | Block writes anywhere except `.hall-cache/` |
| `SessionStart` | `session-start.sh` | Detect interrupted sessions; verify gitignore |
| `Stop` | inline in hooks.json | Kill watcher daemon on session end |

### Background Watcher

`watcher.sh` runs as a background daemon during the session (started at Step 3 of `/hall:open`, killed at Step 2 of `/hall:close`). It polls GitHub every `$POLL_INTERVAL` seconds (default 120) and emits events on state transitions.

**Detected events:**

| Event key | Trigger condition |
|---|---|
| `LABEL_IN_PROGRESS` | `hall:in-progress` appears in issue labels |
| `LABEL_AWAITING_INPUT` | `hall:awaiting-input` appears in issue labels |
| `LABEL_POST_MORTEM` | `hall:post-mortem` appears in issue labels |
| `PR_OPENED` | A PR linking this issue transitions from absent to `state=open` |
| `PR_MERGED` | PR `mergedAt` becomes non-null |
| `PR_CLOSED_NO_MERGE` | PR `state=closed` and `mergedAt` is null |
| `REFINE_READY` | New commit on PR branch while task is REVIEWING with `review_cycle=1` |

Events are emitted only on transition (compared to `.hall-cache/watcher-state.json`). Two output channels:
- **Stdout** → captured to `.hall-cache/watcher.log` via `nohup`
- **JSONL append** → `.hall-cache/watcher-events.jsonl` (drained by `/hall:reconcile` Step 0)

**Autonomous loop:**

```
watcher.sh (every 120s)
  └─ polls GitHub → writes watcher-events.jsonl + watcher.log

CronCreate job (every 7 min, set by /hall:open Step 6)
  └─ wakes Old Major
       └─ /hall:reconcile (Step 0: drains watcher-events.jsonl)
            └─ /hall:dispatch → advances plan without user input
```

---

## 10. MCP Servers

Declared in `.mcp.json`. Portable — no project-specific configuration required except credentials via environment variables.

| Server | Command | Used by | Purpose |
|---|---|---|---|
| `sequential-thinking` | `npx @modelcontextprotocol/server-sequential-thinking` | Old Major + Tier-2 subagents | Structured multi-step reasoning |
| `fetch` | `uvx mcp-server-fetch` | Old Major + advisory subagents | Pull URLs (papers, live sites, RFCs) |
| `github` | HTTP `https://api.githubcopilot.com/mcp/` | Old Major | Issue, label, and PR operations beyond `gh` CLI |
| `google-drive` | HTTP `https://drivemcp.googleapis.com/mcp/v1` | Old Major | Read design docs and specs from Drive on user request |

`github` requires `GITHUB_PERSONAL_ACCESS_TOKEN`. `google-drive` requires Google OAuth — users must authenticate via `claude mcp auth` on first use.

---

## 11. Known Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Persona injection doesn't sustain across long sessions | Stack assembly file is editable mid-session; `SessionStart` hook re-asserts overlay automatically |
| Old Major writes code despite the constraint | `PreToolUse` hook intercepts all writes outside allowed paths and refuses |
| Bulk dispatch worsens the invoker-pool race | Mandatory 15 s jitter between issue creations within each ready set |
| Quota exhaustion / thundering-herd retry storm | Steward dispatch holds surplus tasks locally rather than queuing; user can override with explicit warning |
| Plan diverges from GitHub state | Reconciliation runs before every dispatch; GitHub wins on conflict |
| Persona cache goes stale | 24 h TTL; `/hall:doctor` shows cache age; `--refresh` forces re-fetch |
| User not an authorized Hall invoker | Invoker detection gate (Step 7) verifies membership; non-invokers get local mode — inline orchestration, no Hall dispatch. See §14. |
| User's project already has a `CLAUDE.md` | Detected at first `/hall:open`; user prompted to append or warned; never silently overwritten |
| `.hall-cache/` accidentally committed | `SessionStart` hook verifies gitignore and re-adds if missing |
| Target org doesn't have Hall App installed | Invoker detection gate checks Hall repo presence; absent org → local mode automatically |

---

## 12. Cross-Invoker Sync

Coordinates work across multiple Hall sessions on the same target repo using GitHub Projects v2 as a shared source of truth.

### Board architecture

GitHub Projects v2 is the team-visible kanban layer across all Hall sessions on a repo. Board items are GitHub Issues linked to Projects v2. The local `plan.json` is the implementation scratchpad; the board surfaces status for product and team visibility.

**Invoker-scope write rule:** each Old Major only mutates board items where the `Invoker` field matches the session login. Items owned by other invokers receive a `post_comment` call instead — cross-session reads are always permitted, writes are scoped.

### Hall Projects MCP server (`mcp/hall-projects-server.py`)

Installed into the workspace `.mcp.json` at `hall:open` Step 3 via `templates/mcp-hall-projects-snippet.json`. Requires `GITHUB_TOKEN` or `GITHUB_PERSONAL_ACCESS_TOKEN` at startup. GraphQL query strings live in `mcp/_queries.py`.

Exposes five tools:

| Tool | Behaviour |
|---|---|
| `get_project_meta` | Resolves project ID and all field/option IDs; persists to `board-meta.json` |
| `list_items` | Fetches one page (up to 100 items); caller paginates via `pageInfo` |
| `update_item_field` | Updates one field; enforces invoker-scope; returns `item_not_in_board` if item absent from `board.json`, `invoker_mismatch` if the Invoker field doesn't match |
| `post_comment` | Posts a comment on a linked issue; permitted on items owned by any invoker |
| `read_board` | Fetches all pages, writes `board.json`, returns item count |

### Board provisioning (`/hall:init-board`)

Idempotent — skips anything that already exists. Sequence: resolves repo/owner type; creates the Projects v2 board; creates custom fields (Status, Invoker, Priority, Epic); creates repo labels; runs `GetProjectMeta` and persists `board_project_number` and `board_project_id` to `.hall-cache/session/config.json`, field metadata to `.hall-cache/session/board-meta.json`.

### Board context injection (`scripts/fetch-board-context.sh`)

Called non-fatally at `hall:open` Step 3. Resolves the project node ID in priority order: `config.json → board-meta.json → GetProjectMeta` GraphQL call. Paginates `ListItems` (max 2 pages / 200 items).

Writes `.hall-cache/session/board-context.md`: active-item table (number, title, status, invoker, priority, epic), done-item count, and a cross-invoker note when items from other invokers are present.

`templates/CLAUDE-stack.md.tpl` `@`-imports `board-context.md` as its last entry. The import is a no-op when the file is absent (board not provisioned, or fetch failed silently).

### Board write hooks

**`hall:dispatch` Step 5** — after filing each issue, locates the matching item in `board.json` by issue number and calls `update_item_field` to set Status → "In Progress". Skips silently if `board_project_number` is absent from `config.json` or if the item is not in `board.json`.

**`hall:reconcile` Board writes** — for each task newly transitioning to REVIEWING, MERGED, or DONE:
- Own item (Invoker matches session login): calls `update_item_field` — Status → "In Review" for REVIEWING, "Done" for MERGED/DONE.
- Foreign item: calls `post_comment` to notify instead.

All board errors are logged; reconcile never aborts on a board write failure.

### Cross-invoker conflict detection

Phase 3 of `methodology/decomposition.md`. Runs during project decomposition before dependency mapping — but only when `board-context.md` is present and contains active items from other invokers. Silent no-op on solo sessions.

Three overlap heuristics applied against each proposed task:
- **Same file or directory target** — task and active board item both reference the same file or directory
- **Same domain keyword** — shared terms (`hall:open`, `reconcile`, `MCP`, `board`, etc.) place both tasks in the same area
- **Explicit dependency** — the proposed task would modify something another invoker is actively building

Each hit produces a `CROSS-INVOKER RISK` entry with a recommended action (`coordinate via post_comment` | `block until resolved` | `proceed with explicit note`). Plan confirmation is gated on invoker acknowledgement.

---

## 13. Invoker Detection

`hall:open` Step 7 asks once: *"Are you a Hall invoker?"* The result is cached in `.hall-cache/invoker.json` and skipped on subsequent opens. To re-verify: `hall:open --verify` (deletes the cache in-session) or `hall-prune --invoker` (clears for next open).

### Decision logic

Two checks run against the current org:

| Check | Test |
|---|---|
| `hall_repo` | `repos/{org}/hall-of-automata` exists and responds |
| `team_member` | authenticated user is in `automata-invokers` team |

| `hall_repo` | `team_member` | Outcome |
|---|---|---|
| `false` | — | local (Hall not installed in org) |
| `true` | `false` | local (not a team member) |
| `true` | `unknown` | invoker + WARN (token lacks `read:org` scope) |
| `true` | `true` | invoker |

### Cache schema

`.hall-cache/invoker.json`:

```json
{
  "mode": "invoker | local",
  "verified_at": "<ISO timestamp>",
  "checks": { "hall_repo": true, "team_member": true }
}
```

### Invoker path

Full dispatch mode: Old Major files Hall issues, the watcher monitors GitHub state, and the autonomous cron drives reconcile. Automation Q&A runs immediately after verification (see §16.1).

### Local path

`config.json` receives `local_mode: true`, `automation_level: 0`. See §14 for behavior.

---

## 14. Local Mode

Active when `.hall-cache/session/config.json` contains `local_mode: true`. Set by the invoker detection gate when the user is not in `automata-invokers` or the Hall is absent from the org.

### What it is

Inline orchestration: Old Major plans and implements tasks without filing GitHub Issues. The Hall's sandboxed runners, quota system, and dispatch mechanics are bypassed entirely.

### Persona load path

Before each task, Old Major reads `.hall-cache/personas/<specialist>.md` for the assigned specialist and follows that persona's domain methodology and coding standards. Old Major's voice remains unchanged throughout — the persona informs the work, not the narrator.

### Branch convention

`local/<task-slug>` — e.g., `local/invoker-dispatch-gate`.

### Result artifact

Written at task completion:

```
.hall-cache/plans/<plan-slug>/local-runs/<task-id>/result.md
```

Fields: `Persona consulted`, `Branch`, `Status` (`DONE | BLOCKED | PARTIAL`), `Summary`, `Files changed`.

### Wave advancement

Manual. After each task completes, Old Major proposes the next ready set and waits for explicit user confirmation. No watcher daemon, no cron-driven advancement.

### Scope

Local mode operates in the current working directory. Tasks requiring pushes to external repos or PRs outside the current session cannot be completed in local mode. Old Major states the limitation explicitly when a task hits this boundary and suggests setting up as an invoker.

---

## 15. Command Reference

| Command | Purpose |
|---|---|
| `/hall:open [--refresh\|--verify]` | Enter session mode. Preflight → fetch personas → assemble stack → invoker detection gate → activate Old Major. `--verify` forces invoker re-check. |
| `/hall:close` | Exit session mode. Clean session files; kill watcher. |
| `/hall:doctor` | Full preflight diagnostic: auth, Hall App, invoker/local mode status, gitignore, cache, MCPs, quota. |
| `/hall:plan` | Dump current plan as JSON + Markdown + Mermaid dependency diagram. |
| `/hall:status` | Render plan board: in-flight, awaiting input, blocked, ready, done, failed. |
| `/hall:dispatch [--single <id>] [--dry-run]` | Dispatch ready tasks. Old Major normally proposes this in conversation. |
| `/hall:reply <task_id> <message>` | Post reply on an issue carrying `hall:awaiting-input`, triggering re-dispatch. |
| `/hall:reconcile` | Resync local plan from GitHub. Runs implicitly before any dispatch. |
| `/hall:consultations [list\|view <id>\|prune]` | Manage saved Tier-2 consultation outputs. |
| `/hall:prune [--invoker] [--plans <days>] [--cache]` | Clear invoker cache (`--invoker`), clean old plan directories, or flush persona cache. |

---

## 16. PR Review Agent

Keeps non-technical invokers out of the merge loop. When active, Old Major dispatches a review pass after every specialist PR using the specialist's own persona in reviewer mode.

### 16.1 Automation configuration

Asked once at `hall:open` Step 7 (invoker path only) when the config entry is absent from `.hall-cache/session/config.json`. Two binary questions:

1. **Auto-review?** — Should Old Major automatically dispatch a review after each specialist PR?
2. **Auto-merge?** — If the review verdict is LGTM, should Old Major merge without invoker action?

Resulting levels:

| Level | Auto-review | Auto-merge | Behavior |
|---|---|---|---|
| 0 — Hands-on | No | No | Dispatch only; invoker reviews and merges |
| 1 — Assisted | Yes | No | Review agent posts verdict; invoker merges |
| 2 — Auto-merge | Yes | Yes | Review agent posts verdict; LGTM auto-merges |

Config is stored in `.hall-cache/session/config.json` and re-used across commands within the session.

### 16.2 Review loop — Act → Assess → Settle

```
1. ACT       Specialist opens PR against issue acceptance criteria
2. ASSESS    Reviewer posts structured verdict:
               LGTM    → SETTLE
               MINOR   → REFINE (one cycle permitted)
               MAJOR   → SETTLE (escalate, no loop)
               BLOCKED → SETTLE (escalate, no loop)
3. REFINE    Specialist addresses MINOR findings (one shot)
4. ASSESS-2  Reviewer posts final verdict — always terminal:
               LGTM    → SETTLE
               any     → SETTLE (escalate)
5. SETTLE    Auto-merge if level 2 and LGTM; otherwise flag invoker
```

**Loop prevention:** only MINOR findings enter the REFINE cycle. MAJOR and BLOCKED go directly to SETTLE. ASSESS-2 is unconditionally terminal — the second verdict cannot trigger another REFINE regardless of severity.

**Verdict format** (required in all reviewer comments):

```
VERDICT: <LGTM | MINOR | MAJOR | BLOCKED>
FINDINGS:
- <finding> [severity: minor | major]
NEXT: <merge | address-and-resubmit | escalate-to-invoker>
```

### 16.3 Reviewer overlay

Each review pass uses the specialist's persona wrapped in a `reviewer-overlay.md.tpl` baseline. The overlay loads `automaton_base.md`, the specialist persona, and `review-loop.md`, then issues four read-only instructions:

1. Fetch the diff via `gh pr diff --repo <REPO>`
2. Fetch the issue via `gh issue view --repo <REPO>` to extract acceptance criteria
3. Assess every criterion against the diff using the verdict taxonomy from `review-loop.md`
4. Return the structured verdict block — no output before or after it

The reviewer must not post, write, or create anything. The verdict text is returned to Old Major, who posts it via `gh pr comment --repo`, then submits a GitHub PR review: `--approve` for LGTM, `--request-changes` for MINOR/MAJOR/BLOCKED. On ASSESS-2, the overlay appends a terminal-cap notice to the verdict block.

The reviewer is the same specialist who implemented the task — domain knowledge travels with the persona without re-establishing context.

### 16.4 Trigger mechanism

`hall:reconcile` sets `needs_review: true` on any task that newly transitions to REVIEWING when `automation_level ≥ 1`. `hall:dispatch` Step 0 processes these before the normal ready set:

1. Locate the open PR for the task's issue.
2. Render the reviewer overlay into `.hall-cache/session/claude-agents/<specialist>-reviewer.md`.
3. Spawn the reviewer subagent with the PR number, issue number, and current review cycle.
4. Post the returned verdict block via `gh pr comment --repo`.
5. Route by verdict: LGTM → SETTLE; MINOR at `review_cycle == 1` → REFINE (set `review_cycle: 2`, requeue REVIEWING); any ASSESS-2, MAJOR, or BLOCKED → SETTLE.

At SETTLE: LGTM at automation level 2 triggers `gh pr merge --merge`; otherwise the invoker is flagged. Terminal outcomes advance the task to DONE or ESCALATED.

---

## 17. Future Work

| Feature | Notes |
|---|---|
| Complex git workflow support | Currently assumes merge = main. Opt-in via explicit context. |
| Plugin release process | Document how to tag, package, and publish a new CLI plugin version. |
| Repoless / HQ mode | Run Old Major without a target repo — pure planning and coordination, no dispatch. Useful as a command-and-conquer HQ for orchestrating across many repos simultaneously. |

---

## 18. Reference Architecture

```
┌─────────────────────────────────────────┐
│            Developer's laptop           │
│                                         │
│  Claude Code session = Old Major        │
│    reads/writes .hall-cache/            │
│    spawns Tier-2 advisory subagents     │
│    uses: sequential-thinking            │
│           fetch · github · google-drive │
└─────────────────┬───────────────────────┘
                  │ gh CLI: file issues,
                  │ read state, post replies
                  ▼
        ┌─────────────────────┐
        │       GitHub        │
        │  Issues tagged      │
        │  hall:<specialist>  │
        │  Pull requests      │
        │  Status comments    │
        └──────────┬──────────┘
                   │ webhook triggers workflow
                   ▼
        ┌─────────────────────┐
        │  Hall infrastructure│
        │  Specialist runner  │
        │  (sandboxed, full   │
        │   tooling)          │
        └─────────────────────┘
```

**Three invariants:**
1. The plugin's only connection to the Hall is via GitHub.
2. Personas flow one way: upstream repo → `.hall-cache/` → session context. Never back.
3. The Hall's infrastructure is unchanged; the plugin uses the [documented direct dispatch path](https://mockasort-studio.github.io/hall-codex/how-to-invoke/#use-case-4-direct-agent-dispatch-power-users).
