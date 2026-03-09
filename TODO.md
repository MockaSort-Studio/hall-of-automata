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
  - _(No usage vars — HALL_USAGE_COUNT and HALL_WEEKLY_CAP live in `invoker/<handle>`, not `hall/<agent>`)_
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

### ✅ Code tasks — keeper env variables (replace Actions Cache counter)

- [x] `actions/counter/action.yml`: replace cache-based counter with Environments API read/write on `HALL_USAGE_COUNT`
- [x] Cap check in dedicated `check-invoker-cap` job (runs in `invoker/<handle>` env); dispatch job guarded at job level
- [x] `scripts/check-weekly-cap.sh`: inlined into `check-invoker-cap` job; file retained but no longer called
- [x] Weekly reset: `weekly-reset.yml` scheduled workflow zeroes `HALL_USAGE_COUNT` every Monday 00:00 UTC

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

### ✅ Code tasks — unauthorized invocation hardening (FR-17)

- [x] `actions/authorize`: hard `core.setFailed()` + label removal + comment in one combined step
- [x] All `if: steps.auth.outputs.authorized == 'true'` guards removed from `invoke.yml`

### ✅ Code tasks — dispatch outcome contract

- [x] `automaton_base.md`: agent must write `.hall/dispatch-result.json` with full outcome enum (`pr_created`, `awaiting_input`, `comment_posted`, `quota_exceeded`, `failed`)
- [x] `scripts/find-agent-pr.js`: reads dispatch-result.json first, falls back to API branch query
- [x] `scripts/resolve-final-stage.sh`: maps all outcome values to status-card stages incl. `queued`
- [x] `actions/status-card/action.yml`: `comment-posted`, `queued`, `failed` stage labels added
- [x] `post-dispatch`: `outcome` input uses `steps.final.outputs.stage` (semantic) not step conclusion

### ✅ Code tasks — co-authorship (FR-16)

- [x] Co-authored-by instruction in `automaton_base.md`; verify claude-code-action honours commit trailers in live test

### ✅ Code tasks — cleanup finalization

- [x] `post-dispatch`: semantic `outcome` fixed (uses `steps.final.outputs.stage`)
- [ ] `actions/cleanup`: make summary comment mandatory (remove `if: inputs.issue-number != ''` guard for comment step)
- [ ] `hall-cleanup.yml` detect step: extract inline JS to `scripts/detect-cleanup-context.js`

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

### Phase A — Onboarding smoke (TEST_PLAN.md Phase A)

> Blocking. Nothing else is testable without registered invokers and automata.

- [ ] 👤 Provision `hall/old-major` environment (secret `CLAUDE_CODE_OAUTH_TOKEN` only — no usage vars)
- [ ] 👤 Provision `hall/roster` environment + seed deployment
- [ ] 👤 Create all labels (`hall:onboard-invoker`, `hall:onboard-automaton`, `hall:active-invoker`, `hall:awaiting-input`, `hall:queued`, `hall:invoker-queued`)
- [ ] 👤 Verify GitHub App permissions (environments, deployments, contents, issues: write)
- [ ] Run TC-INV-01 through TC-INV-05 (invoker onboarding)
- [ ] Run TC-AUT-01 through TC-AUT-04 (automaton onboarding)

### Phase B — Task dispatch baseline (TEST_PLAN.md Phase B)

> Requires at least one registered invoker and `hall/hamlet` provisioned via onboarding.

- [ ] Run TC-01 (label trigger, authorized)
- [ ] Run TC-02 (@mention trigger)
- [ ] Run TC-03 (unauthorized hard-fail)
- [ ] Run TC-04 (cap exceeded)
- [ ] Run TC-05 + TC-06 (awaiting-input state + re-dispatch)
- [ ] Run TC-07 (PR review → re-dispatch)
- [ ] Run TC-08 + TC-09 (CI loop + escalation)
- [ ] Run TC-10 + TC-11 (cleanup on merge and close)
- [ ] Run TC-12 (weekly counter)

### Phase C — Code tasks (post Phase B green)

In priority order:

1. **Unauthorized hardening + cleanup fixes** — smallest scope, highest safety impact
   - `actions/authorize`: hard `core.setFailed()` + tag `@automata-invokers` in rejection
   - Remove `if: steps.auth.outputs.authorized == 'true'` guards (hard fail makes them redundant)
   - `actions/cleanup`: make summary comment mandatory; extract detect JS; fix `outcome` semantics

2. **Keeper env variables** — replace Actions Cache counter
   - `actions/counter`: read/write `HALL_USAGE_COUNT` via Environments API
   - Remove `check-weekly-cap.sh` gate from dispatch job; cap check moves to pre-dispatch guard
   - Add weekly reset scheduled workflow

3. **Persona injection model**
   - Fetch persona from gist URL in deployment payload instead of repo file copy
   - Stash target repo `CLAUDE.md` as `.hall-local.md` before overwriting
   - Remove `inject-ci-context.sh` and `append-review-context.sh` (context synthesis moves to Old Major)

4. **Old Major triage + assignment trigger**
   - `invoke.yml`: add `issues.assigned` trigger; add `triage` job (Old Major selects agent + context)
   - `detect-invoke-context.js`: assignment path detection

5. **Deployment lifecycle**
   - `actions/post-dispatch`: update `hall/<agent>` deployment after each dispatch
   - `actions/cleanup`: append completed-task entry to dashboard gist on PR close

### Phase D — Webhook relay + full org test

- Fly.io relay for cross-repo event routing
- Full org smoke test across multiple target repos

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
