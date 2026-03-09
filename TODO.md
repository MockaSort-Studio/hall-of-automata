# Hall of Automata — Dev Log

> Legend: ✅ done · 🔧 code task · 👤 keeper task · ⚠️ known gap · 📐 design task

---

## Status

**Phases 1–4 complete. Phase 5 (architecture redesign per Lore Keeper review) is in progress — documentation rewritten, implementation not yet started.**

The system works end-to-end for a single named-agent dispatch. Before implementing Phase 5 code changes, run the smoke test on the hall repo to establish a working baseline.

---

## What was built (Phases 1–4)

### Prerequisites (👤)
- GitHub App registered (`hall-of-automata[bot]`), App ID and private key stored as repo secrets
- Bot avatar uploaded
- `hamlet` keeper OAuth token generated via `claude setup-token`, stored in `hall/hamlet` Environment
- `automata-invokers` team verified
- Trigger labels created in target repos

### Phase 1 — Repo structure
- `agents.yml` · `routing.yml` · `actions/` skeletons · `roster/hamlet.md` as persona file
- Generic `invoke.yml` replaces per-agent workflow files

### Phase 2 — Dispatch core
- `actions/authorize` — team membership gate, rejection comment, label removal
- `actions/status-card` — upsert `<!-- hall-status -->` comment across full lifecycle
- `actions/counter` — weekly invocation counter via Actions Cache
- `actions/dispatch` — runs `claude-code-action@v1` with OAuth token and persona
- `actions/post-dispatch` — applies `hall:{agent}` label to opened PR, uploads audit artifact
- `invoke.yml` — two-job workflow: detect trigger context → dispatch agent

### Phase 3 — Task lifecycle
- `actions/memory` — save/restore task JSON blob via Actions Cache (keyed by PR)
- `hall-ci-loop.yml` — detects failing CI on `hall/*` branches, re-dispatches or escalates
- `invoke.yml` pr_review path — restores memory, appends review feedback, re-dispatches
- Keeper escalation — @mention on PR after `max_retries` exhausted
- `hall-cleanup.yml` + `actions/cleanup` — deletes memory, removes labels, posts issue summary

### Phase 4 — Polish
- `scripts/` — all inline bash and JS extracted from workflows into standalone files
- `awaiting-input` state — status card stage + `hall:awaiting-input` label + auto-re-dispatch on human reply
- Issue template updated with `@mention` + label invocation instructions
- Docs reconciled: `secrets-model.md`, `runner-model.md`, `federation/joining.md`, `roster/hamlet.md`

---

## Phase 5 — Architecture redesign (Lore Keeper review)

> Design documents updated. Implementation not started. Smoke test first.

### 📐 Design changes (complete)
- `codex/design_document.md` — UC-1/4/5/6 revised; FR-12 through FR-18 added; NFR-1 updated; storage table updated; Appendix C updated
- `codex/architecture/README.md` — new architecture diagram with all components
- `codex/architecture/runner-model.md` — persona injection model, new execution layers
- `codex/architecture/secrets-model.md` — env variables, deployment payloads, keeper topology
- `agents/automaton_base.md` — canonical base contract (merged from base-behavior_old.md)
- `agents/automaton_template.md` — character sheet format (replaces Jinja2 template)
- `agents/personality-guide.md` — updated to gist-hosted personas, catalog entry concept
- `roster/old-major.md` — full character sheet
- `agents.yml` — new schema with `display_name`, `catalog` block, `old-major` entry

### � Keeper prerequisites — provision before first test

These must exist before any workflow run that routes to Old Major.

- [ ] Create GitHub Environment `hall/old-major` in repo Settings → Environments
  - Secret: `CLAUDE_CODE_OAUTH_TOKEN` — mksetaro's Claude OAuth token (`claude setup-token`)
  - Variable: `HALL_USAGE_COUNT` = `0`
  - Variable: `HALL_WEEKLY_CAP` = `25`
- [ ] Create GitHub Environment `hall/roster` in repo Settings → Environments
  - No secrets needed at this stage — Old Major writes the deployment payload
  - Create an initial inactive deployment so the environment exists: `gh api repos/{owner}/{repo}/deployments -f ref=main -f environment=hall/roster -f description="Roster seed" -f auto_merge=false -F required_contexts=[]`
- [ ] Verify the GitHub App has permissions: `environments: write`, `deployments: write`, `contents: write`, `issues: write`

**First test — onboarding smoke:**
1. File a `new-automaton` issue using the template (fill in a real or dummy character sheet)
2. Template auto-applies `hall:old-major` → `invoke.yml` fires, dispatch job runs in `hall/old-major` env
3. Old Major reads the issue, creates the persona gist, creates the keeper environment, seeds the roster deployment, updates `agents.yml`, posts keeper instructions on the issue
4. Verify each artifact exists before proceeding to Phase 5 code tasks

---

### �🔧 Code tasks — new invocation path (Old Major triage)

- [ ] `invoke.yml`: add `assignment` trigger (`issues.assigned` to `@hall-of-automata`)
- [ ] `invoke.yml`: add `triage` job — runs in `hall/old-major` env, reads roster catalog from `hall/roster` deployment, outputs `selected_agent` + `task_context`
- [ ] `invoke.yml`: dispatch job reads from both detect (labeled path) and triage (assignment path) outputs
- [ ] `scripts/detect-invoke-context.js`: add assignment path detection
- [ ] `roster/old-major.md`: persona already written; Old Major env + deployment must be provisioned (👤)

### 🔧 Code tasks — keeper env variables (replace Actions Cache counter)

- [ ] `actions/counter/action.yml`: replace cache-based counter with Environments API read/write on `HALL_USAGE_COUNT`
- [ ] `invoke.yml` dispatch job: remove `check-weekly-cap.sh` shell gate; cap check moves to Old Major triage (unlabeled path) and to a single pre-dispatch guard (labeled path)
- [ ] `scripts/check-weekly-cap.sh`: deprecate or scope to labeled-path pre-dispatch guard only
- [ ] Add weekly reset logic (scheduled workflow to zero `HALL_USAGE_COUNT` on reset day)

### 🔧 Code tasks — deployment lifecycle

- [ ] Create `hall/roster` environment + seed deployment with hamlet catalog entry (👤 + 🔧)
- [ ] `actions/post-dispatch`: update `hall/<agent>` deployment after dispatch (status + audit append)
- [ ] `actions/cleanup`: append completed-task entry to dashboard gist on PR close
- [ ] Onboarding workflow (new): issue template → Old Major → creates env + deployment + gists → instructs keeper

### 🔧 Code tasks — persona injection model

- [ ] `invoke.yml` dispatch job: fetch persona from gist (via deployment payload) instead of copying roster file
- [ ] `invoke.yml` dispatch job: stash target repo CLAUDE.md as `.hall-local.md` before writing Hall's CLAUDE.md
- [ ] `actions/dispatch`: pass task context as `prompt` input (currently unused path)
- [ ] Remove `scripts/inject-ci-context.sh` and `scripts/append-review-context.sh` — context synthesis moves to Old Major or prompt construction

### 🔧 Code tasks — unauthorized invocation hardening (FR-17)

- [ ] `actions/authorize`: change failure mode from soft-exit to hard `core.setFailed()` + tag `@automata-invokers` team in rejection comment
- [ ] Remove all `if: steps.auth.outputs.authorized == 'true'` guards in `invoke.yml` (hard fail makes them unnecessary)

### 🔧 Code tasks — co-authorship (FR-16)

- [ ] Add co-authored-by instruction to `automaton_base.md` prompt (done) — verify claude-code-action honors commit trailers
- [ ] Add git commit hook or post-dispatch check if needed

### 🔧 Code tasks — cleanup finalization

- [ ] `actions/cleanup`: make summary comment mandatory (remove `if: inputs.issue-number != ''` guard for comment step)
- [ ] `hall-cleanup.yml` detect step: extract inline JS to `scripts/detect-cleanup-context.js`
- [ ] `post-dispatch`: fix semantic `outcome` (use `steps.final.outputs.stage` not step conclusion)

---

## Open items (known gaps, unchanged from Phase 4)

| Item | Impact | Priority |
|------|--------|----------|
| No webhook relay | Hall only reacts to its own repo events | Before full org use |
| FR-9 routing implementation | Cap exceeded → queue instead of route | Phase 5 |
| PR size cap enforcement | No diff size limit | Investigate |
| Agent display names with emoji in status card | Raw slug used | Low |

---

## Order of remaining work

```
Smoke test (TEST_PLAN.md)
  → Phase 5 code: unauthorized hardening + cleanup fixes (smallest scope, highest safety impact)
  → Phase 5 code: keeper env variables (counter replacement)
  → Phase 5 code: persona injection model (gist fetch + CLAUDE.md stash)
  → Phase 5 code: Old Major triage job + assignment trigger
  → Phase 5 code: deployment lifecycle actions
  → Webhook relay (Fly.io)
  → Full org test
```

### Prerequisites (👤)
- GitHub App registered (`hall-of-automata[bot]`), App ID and private key stored as repo secrets
- Bot avatar uploaded
- `hamlet` keeper OAuth token generated via `claude setup-token`, stored in `hall/hamlet` Environment
- `automata-invokers` team verified
- Trigger labels created in target repos

### Phase 1 — Repo structure
- `agents.yml` · `routing.yml` · `actions/` skeletons · `roster/hamlet.md` as persona file
- Generic `invoke.yml` replaces per-agent workflow files

### Phase 2 — Dispatch core
- `actions/authorize` — team membership gate, rejection comment, label removal
- `actions/status-card` — upsert `<!-- hall-status -->` comment across full lifecycle
- `actions/counter` — weekly invocation counter via Actions Cache
- `actions/dispatch` — runs `claude-code-action@v1` with OAuth token and persona
- `actions/post-dispatch` — applies `hall:{agent}` label to opened PR, uploads audit artifact
- `invoke.yml` — two-job workflow: detect trigger context → dispatch agent

### Phase 3 — Task lifecycle
- `actions/memory` — save/restore task JSON blob via Actions Cache (keyed by PR)
- `hall-ci-loop.yml` — detects failing CI on `hall/*` branches, re-dispatches or escalates
- `invoke.yml` pr_review path — restores memory, appends review feedback, re-dispatches
- Keeper escalation — @mention on PR after `max_retries` exhausted
- `hall-cleanup.yml` + `actions/cleanup` — deletes memory, removes labels, posts issue summary

### Phase 4 — Polish
- `scripts/` — all inline bash and JS extracted from workflows into standalone files
- `awaiting-input` state — status card stage + `hall:awaiting-input` label + auto-re-dispatch on human reply
- Issue template updated with `@mention` + label invocation instructions
- Docs reconciled: `secrets-model.md`, `runner-model.md`, `federation/joining.md`, `roster/hamlet.md`

---

## Open items

### 🔧 Semantic `outcome` in audit log

`post-dispatch` receives `outcome: ${{ steps.agent.outcome || 'skipped' }}` which is a GitHub step conclusion (`success`/`failure`/`skipped`), not the semantic outcome defined in Appendix E (`pr_created`, `comment_posted`, `awaiting_input`, `failed`).

Fix: pass `${{ steps.final.outputs.stage }}` as an additional input or derive the semantic outcome from the final stage in `post-dispatch` itself.

---

## Known limitations

| Limitation | Impact | When to fix |
|------------|--------|-------------|
| No webhook relay | Hall only reacts to events on the hall repo itself; target repos don't trigger the Hall automatically | Before real multi-repo use — see relay notes below |
| `post-dispatch` pre-built inputs unused (`turns-used`, `turns-max`, `retry-count`, `rerouted`) | Audit log always shows `0`/`false` for these fields | When FR-9 routing is implemented |
| `hall-cleanup.yml` detect step stays inline JS | Minor style inconsistency; step runs before checkout so extraction would require an extra sparse checkout step | Low priority |
| PR size cap (800 LOC) | No limit on how large an agent's PR diff can be | Investigate: persona instruction vs. post-dispatch CI gate; configurable per agent in `agents.yml` |
| Agent display names with emoji | Status card and comments use the raw slug (`hamlet`) not the display name (`hamlet 🐗`) | Add `display_name` field to `agents.yml`; update status-card and comment templates |

---

## Webhook relay — 👤 next infrastructure task

**Why it's needed.** GitHub delivers workflow events only to the repo where the event occurs. The Hall's `invoke.yml` currently only fires on events within the hall-of-automata repo itself. For true org-wide operation, a relay is required.

**What it does:**
1. Receives GitHub App webhook (any org repo event)
2. Validates signature with the App's webhook secret
3. Calls `POST /repos/MockaSort-Studio/hall-of-automata/actions/workflows/invoke.yml/dispatches` with the event payload forwarded as `workflow_dispatch` inputs

**Hosting options:** Cloudflare Worker, Fly.io, GitHub App proxy. Fewer than 100 lines. The relay only validates a signature and calls one API endpoint.

**Build it after** a successful end-to-end smoke test on the hall repo (see `TEST_PLAN.md`).

---

## Order of remaining work

```
Smoke test (TEST_PLAN.md) → FR-9 routing → webhook relay → full org test
```
