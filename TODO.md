# Hall of Automata — Dev Log

> Legend: ✅ done · 🔧 code task · 👤 keeper task · ⚠️ known gap · 📐 design task

---

## Status

**Phases 1–4 complete. Phase A smoke test complete. Phase B (task dispatch baseline) is next.**

The system works end-to-end for invoker onboarding, automaton onboarding, and named-agent dispatch. The invoker pool model is live with `mksetaro` as active invoker. Old Major provisioned `mergio` (PR #11). Phase B tests named-agent task dispatch on real issues.

---

## What was built (Phases 1–4)

### Prerequisites (👤)
- GitHub App registered (`hall-of-automata[bot]`), App ID and private key stored as repo secrets
- Bot avatar uploaded
- `automata-invokers` team verified
- Trigger labels created

### Phase 1 — Repo structure
- `agents.yml` · `routing.yml` · `actions/` skeletons · `roster/old-major.md` as persona file
- Generic `invoke.yml` replaces per-agent workflow files

### Phase 2 — Dispatch core
- `actions/authorize` — team membership gate, rejection comment, label removal
- `actions/status-card` — upsert `<!-- hall-status -->` comment across full lifecycle
- `actions/counter` — weekly invocation counter via Environments API (`HALL_USAGE_COUNT`)
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
- Invoker pool model: `detect-invoke-context.js` pool-selects least-used under-cap invoker
- Weekly reset: `weekly-reset.yml` zeroes `HALL_USAGE_COUNT` every Monday 00:00 UTC
- Token validation hardened: curl 000 fails; only HTTP 429 counts as a valid probe pass
- `agents.yml` `author` field (replaces `invoker`) — credits creator, no runtime binding
- `onboard-automaton.yml`: Old Major creates PR (not direct push); `max_turns` 30; counter increment

---

## Phase A smoke test — COMPLETE ✅

All test cases passed.

- ✅ TC-INV-01 — invoker onboarding happy path
- ✅ TC-INV-02 — duplicate registration rejected
- ✅ TC-INV-03 — invalid token rejected (curl 000 → fail)
- ✅ TC-INV-04 — cap enforcement
- ✅ TC-INV-05 — weekly reset
- ✅ TC-AUT-01 — automaton onboarding (Old Major dispatched)
- ✅ TC-AUT-02 — Old Major creates PR with agents.yml + roster file
- ✅ TC-AUT-03 — PR merged, agents.yml updated on main
- ✅ TC-AUT-04 — counter incremented after Old Major dispatch

---

## Phase B — Task dispatch baseline

> Requires at least one registered invoker. `mergio` is provisioned on main (PR #11 merged).

- [ ] Run TC-01 (label trigger, authorized)
- [ ] Run TC-02 (@mention trigger)
- [ ] Run TC-03 (unauthorized hard-fail)
- [ ] Run TC-04 (cap exceeded → queued)
- [ ] Run TC-05 + TC-06 (awaiting-input state + re-dispatch)
- [ ] Run TC-07 (PR review → re-dispatch)
- [ ] Run TC-08 + TC-09 (CI loop + escalation)
- [ ] Run TC-10 + TC-11 (cleanup on merge and close)
- [ ] Run TC-12 (weekly counter reset)

---

## Phase C — Code tasks (post Phase B green)

In priority order:

### 1. 🔧 Cleanup fixes (small scope, high safety)
- [ ] `actions/cleanup`: make summary comment mandatory (remove `if: inputs.issue-number != ''` guard)

### 2. 🔧 Old Major triage + assignment trigger
- [ ] `invoke.yml`: add `issues.assigned` trigger
- [ ] `invoke.yml`: add `triage` job — pool-selects invoker, dispatches Old Major to read catalog, select agent, synthesize context
- [ ] `invoke.yml`: dispatch job reads from both detect (labeled path) and triage (assignment path) outputs
- [ ] `scripts/detect-invoke-context.js`: add assignment path detection

### 3. ⚠️ Known gaps (investigate, no commit yet)
- [ ] PR size cap: enforce 800 LOC limit — persona instruction vs. post-dispatch CI gate; configurable per agent in `agents.yml`
- [ ] Agent display names with emoji in status card (raw slug used, not `display_name`)

---

## Phase D — Webhook relay + full org test

- Fly.io / Cloudflare Worker relay for cross-repo event routing
- Full org smoke test across multiple target repos

**Why it's needed:** GitHub delivers workflow events only to the repo where the event occurs. The Hall's `invoke.yml` currently only fires on events within the hall-of-automata repo itself.

**What it does:**
1. Receives GitHub App webhook (any org repo event)
2. Validates signature with the App's webhook secret
3. Calls `POST /repos/MockaSort-Studio/hall-of-automata/actions/workflows/invoke.yml/dispatches`

**Build after** Phase B passes.

---

## Open items

| Item | Impact | Priority |
|------|--------|----------|
| No webhook relay | Hall only reacts to its own repo events | Before full org use |
| PR size cap not enforced | No diff size limit | Investigate |
| Agent display names with emoji | Raw slug used in status card | Low |
| `post-dispatch` pre-built inputs unused (`turns-used`, `retry-count` always 0) | Audit log incomplete | When FR-9 routing is implemented |
