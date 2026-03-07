# Hall of Automata — Implementation Plan

> Legend: 👤 you · 🔧 code · ⚠️ breaking change

---

## State of the repo vs. the design document

The current repo has a working skeleton: label-triggered dispatch, team-membership auth, basic CLAUDE.md injection, Hamlet roster entry. It was built before the design document and differs in several structural ways:

| Area | Current | Design doc |
|------|---------|------------|
| Auth mechanism | Anthropic API key (`ANTHROPIC_API_KEY`) | Claude OAuth token (`claude_code_oauth_token`) ⚠️ |
| Bot identity | `github-actions[bot]` | `hall-of-automata[bot]` (GitHub App) |
| Agent config | Inline in per-agent workflow files | `agents.yml` + `routing.yml` |
| Persona | Inline `personality-instructions` input | Separate `personas/{agent}.md` files |
| Workflows location | Hall repo `.github/workflows/` | Hall repo `actions/` (reusable) + per-repo callers |
| PR lifecycle | Not handled | CI loop + review loop + cleanup |
| Task memory | None (stateless) | Actions Cache, keyed by PR number |
| Status card | None | In-place comment on issue/PR thread |
| Weekly counter + routing | None | Cache-based counter + least-used routing |
| Audit log | None | Actions Artifact per dispatch |
| Keeper escalation | None | @mention on retry exhaustion |

The `agents/`, `architecture/`, `codex/`, `federation/`, and `roster/` directories are good reference material and should be kept. The workflows need significant restructuring.

---

## 👤 Prerequisites — you do these first

Nothing else can start until these are in place.

### 1. Register the GitHub App ✅

Go to `github.com/organizations/{org}/settings/apps` → New GitHub App.

| Field | Value |
|-------|-------|
| Name | `Hall of Automata` |
| Homepage URL | your org or Hall repo URL |
| Webhook | Active: No (for now — relay server is deferred) |
| Permissions | Contents: R/W · Issues: R/W · Pull Requests: R/W · Members: R · Metadata: R · Checks: R/W |
| Events | `issue_comment`, `issues`, `pull_request`, `pull_request_review`, `check_suite` |
| Where installed | This account (org) |

After creating: note the **App ID** and generate + download a **private key** (`.pem`). Store both as repo secrets in the Hall repo (Settings → Secrets and variables → Actions → New repository secret):
- `APP_ID` → the numeric App ID shown on the App's settings page
- `APP_PRIVATE_KEY` → the full `.pem` file content

These names are used verbatim in `invoke.yml` (`secrets.APP_ID`, `secrets.APP_PRIVATE_KEY`). Do not prefix or rename them.

Install the App at the org level: App settings → Install App → select org → all repositories.

### 2. Find or commission the bot avatar ✅

The `hall-of-automata[bot]` needs a custom avatar. Upload it in the App settings under "Display information". No action blocked on this, but do it early — the identity matters.

### 3. Set up Claude OAuth tokens per agent ✅

On each agent keeper's machine, run:

```sh
claude setup-token
```

This authenticates via Claude Pro/Max and produces an OAuth token. Copy the token — it is only shown once.

### 4. Create GitHub Environments for agents ✅

In the Hall repo: Settings → Environments → New environment.

- Name: `hall/hamlet`
- Add secret: `CLAUDE_CODE_OAUTH_TOKEN` = (paste hamlet keeper's token)
- Set protection rules if desired (e.g., require approval for production use)

Repeat for each agent added to the roster.

### 5. Verify the `automata-invokers` team ✅

Confirm the team exists in the org and has the right members. The authorization logic depends on this team slug — if you rename it, update `agents.yml` accordingly.

### 6. Create the `hall-of-automata` labels in target repos 👤

Each target repo needs:
- `hall:hamlet` (or per-agent) — for PR binding
- `hall:queued` — for queued tasks
- Per-agent trigger labels (`hamlet`, etc.) — these likely already exist

Labels can be created via `gh label create` or the GitHub UI.

---

## Phase 1 — Repo restructuring ✅

**Goal:** get the Hall repo into the shape the design doc describes before adding new logic.

### 1.1 `roster/` is the personas directory

`roster/hamlet.md` already is the agent identity and persona file. No new directory. `agents.yml` references `roster/hamlet.md` as the persona path. The dispatch action reads it and writes its content into CLAUDE.md before the agent runs.

### 1.2 Create `agents.yml`

Centralized agent registry. See Appendix C of design doc for schema. Hamlet entry:

```yaml
agents:
  hamlet:
    environment: hall/hamlet          # GitHub Environment holding the OAuth token
    secret: CLAUDE_CODE_OAUTH_TOKEN
    persona: personas/hamlet.md
    teams: [automata-invokers]
    max_turns: 40
    max_retries: 3
    capabilities: [implement, review, fix, refactor]
    keeper: mksetaro
```

### 1.3 Create `routing.yml`

```yaml
routing:
  weekly_cap: 25
  reset_day: monday
  overrides:
    hamlet:
      weekly_cap: 40
  fallback: queue
  strategy: least_used
```

### 1.4 Scaffold `actions/` directory

Create the skeleton for composite actions (implementations come in Phase 2):

```
actions/
  authorize/action.yml
  status-card/action.yml
  counter/action.yml
  dispatch/action.yml
  post-dispatch/action.yml
  memory/action.yml
  cleanup/action.yml
```

Each is a GitHub composite action with `runs: using: composite`.

---

## Phase 2 — Dispatch core ✅

**Goal:** a working end-to-end dispatch from invocation to agent running on a PR, with status card and counter.

### 2.1 `actions/authorize/action.yml`

Extracted from current `_base-invoke.yml` step 1. Inputs: `org`, `team-slug`, `username`, `org-read-token`. Output: `authorized` (true/false). Posts rejection comment and exits if unauthorized.

### 2.2 `actions/status-card/action.yml`

Creates or updates the `<!-- hall-status -->` comment on the triggering issue or PR.

Inputs: `issue-number`, `repo`, `stage`, `agent`, `dispatched-at`, `branch`, `pr-number`.
Logic: search existing comments for `<!-- hall-status -->` marker; if found, edit it; if not, create it.
Stage values: `dispatching` · `analyzing` · `awaiting-input` · `working` · `pr-opened` · `ci-fix` · `escalated` · `done`.

### 2.3 `actions/counter/action.yml`

Read/write weekly invocation counts from Actions Cache.

- Cache key: `hall-counters-{YYYY}-W{WW}`
- On read: restore cache, parse JSON, return count for requested agent
- On write: increment count, re-save cache
- Schema: Appendix D of design doc

### 2.4 Main dispatch workflow

`.github/workflows/invoke.yml` — generic two-job workflow (replaces deleted `_base-invoke.yml` and `invoke-hamlet.yml`):

- **`detect` job**: resolves `agent`, `issue-number`, `invoker`, `trigger-event`, `repo-owner`, `repo-name` from any trigger. For `workflow_call` the agent comes from `inputs.agent`; for direct triggers it is extracted from label names or `@hall-of-automata[bot]` mentions.
- **`dispatch` job**: runs with `environment: hall/{agent}` (dynamic, computed from detect outputs) and `concurrency: hall-{agent}-{issue-number}`. Calls composite actions in sequence:
  1. `create-github-app-token` — app installation token
  2. Checkout Hall repo → `.hall/`
  3. Read agent config (max-turns, team-slug, keeper) from `agents.yml` via `yq`
  4. `counter` read + cap check via `routing.yml`
  5. `authorize` — gate, exit on failure
  6. `status-card` → stage: `dispatching`
  7. `counter` increment
  8. Checkout target repo (`clean: false`)
  9. Inject persona (`CLAUDE.md`)
  10. `dispatch` — run `claude-code-action@v1` with OAuth token
  11. `status-card` → stage: `done`
  12. `post-dispatch` — upload audit artifact

⚠️ Auth mechanism: `CLAUDE_CODE_OAUTH_TOKEN` comes from the agent's GitHub Environment (not `ANTHROPIC_API_KEY`).

### 2.5 App installation token for bot identity

Replace uses of default `GITHUB_TOKEN` (which posts as `github-actions[bot]`) with the App's installation token (which posts as `hall-of-automata[bot]`).

Use `actions/create-github-app-token@v1` at the start of each job to generate an installation-scoped token from `APP_ID` + `APP_PRIVATE_KEY`. Pass this token to all API calls and to the claude-code-action.

---

## Phase 3 — Task lifecycle 🔧 ← next

**Goal:** the full loop from PR open through CI, review, memory, and cleanup.

### 3.1 `actions/memory/action.yml`

Save and restore task memory from Actions Cache.

- Cache key: `hall-task-{repo}-{pr_number}`
- On save: write JSON blob to cache (approach, files changed, CI failures, review feedback, retry count)
- On restore: attempt cache restore; if miss, pass thread URL to agent as fallback context

### 3.2 CI orchestration loop

New workflow: `.github/workflows/hall-ci-loop.yml`

- Trigger: `check_suite` (completed) or `issue_comment` (created, bot author)
- Condition: event is on a PR labeled `hall:{agent}`
- Logic:
  1. Identify bound agent from PR label
  2. Restore task memory (or fall back to thread)
  3. Read CI check run conclusions via API
  4. Re-dispatch agent with failure context + memory
  5. Update status card → stage: `ci-fix (attempt N/max)`
  6. If `retry_count >= max_retries` → escalate (see 3.4)

### 3.3 Review interaction loop

Extend the existing `pull_request_review` trigger (currently in `invoke-hamlet.yml` Mode 3).

Refactor to:
1. Confirm PR has `hall:{agent}` label
2. Confirm reviewer is a human (`user.type == 'User'`)
3. Restore task memory
4. Re-dispatch agent with review feedback + memory
5. Save updated memory after dispatch

### 3.4 Keeper escalation

When `retry_count >= max_retries`:
1. Post PR comment: `@{keeper} — retries exhausted. Last failure: [summary]`
2. Update status card → stage: `escalated`
3. Do not re-dispatch

Keeper handle comes from `agents.yml` per agent.

### 3.5 Cleanup workflow

New workflow: `.github/workflows/hall-cleanup.yml`

- Trigger: `pull_request` (closed) on PR with any `hall:*` label
- Logic:
  1. Delete `hall-task-{repo}-{pr}` cache entry
  2. Remove `hall:{agent}` label from PR
  3. If PR linked to issue: post summary comment on issue
  4. Update status card → stage: `done`

---

## Phase 4 — Audit & polish 🔧

### 4.1 `actions/post-dispatch/action.yml`

Runs after every successful dispatch:
- Increment weekly counter in cache
- Upload invocation JSON as Actions Artifact (schema: Appendix E of design doc)
- Apply `hall:{agent}` label to any PR the agent opened
- Update status card to current stage

### 4.2 Awaiting-input state

Add logic in the dispatch workflow to detect when the agent has posted a question (no PR opened, no code committed). Set status card → stage: `awaiting-input`. No re-dispatch until a non-bot `issue_comment` arrives on the issue.

This is event-driven: the existing `issue_comment` trigger already handles re-dispatch. The key is the status card update and NOT auto-closing or timing out.

### 4.3 Update issue template

Update `.github/ISSUE_TEMPLATE/automaton-task.yml`:
- Change invocation instruction from "apply label" to `@hall-of-automata <agent>` comment model (FR-1a)
- Keep label model as alternative (FR-1b)
- Add note that the Hall will post a status card as first response

### 4.4 Reconcile old docs

`architecture/`, `codex/`, and `federation/` are kept. They contain useful rationale and process docs. Some are stale relative to the design doc (API keys vs OAuth tokens, etc.) — update them in place rather than deleting.

Priority updates:
- `architecture/secrets-model.md` → OAuth tokens + GitHub Environments instead of org secrets
- `architecture/runner-model.md` → composite actions + GitHub App model
- `federation/joining.md` → `claude setup-token` onboarding flow
- `roster/hamlet.md` → reference `agents.yml` as canonical config source

---

## Deferred

These are explicitly out of scope for the first working version.

| Item | Why deferred |
|------|-------------|
| Webhook relay server | Requires persistent HTTPS endpoint. Direct Actions triggers cover MVP. Needed when: multi-repo org wants zero per-repo config. |
| Org `.github` repo split | Shareability enhancement. Hall repo actions already reusable; split is an install-UX improvement, not a functional one. |
| Hall-owned Check Runs | Appendix B/design doc: deferred. `checks:write` permission should be requested upfront (no re-approval later). |
| Scheduled queue drain (UC-6 full) | `hall:queued` label logic is simple; the scheduled re-dispatch on counter reset is a separate cron workflow. Not needed for core loop. |

---

## Order of execution

```
Prerequisites (👤) → Phase 1 (structure) → Phase 2 (dispatch core) → smoke test
→ Phase 3 (lifecycle) → Phase 4 (polish) → full end-to-end test
```

Do not start Phase 2 before the GitHub App and OAuth tokens are in place — the App token and OAuth credential are load-bearing for everything downstream.

---

## Open questions / constraints to investigate

- **PR size cap (800 LOC):** Analyse whether enforcing a hard upper bound on output PR diff size (e.g. 800 LOC) is a viable scope constraint. If the required change would exceed the cap the agent should decline and reply to the originating comment explaining why the task is too large to implement in a single PR, rather than opening an oversized PR. Investigate: where the check fits (pre-dispatch persona instruction vs. post-dispatch CI gate), how to measure LOC reliably across added/removed lines, and whether the cap should be configurable per agent in `agents.yml`.
