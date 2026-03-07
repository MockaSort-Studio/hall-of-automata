# Hall of Automata — Dev Log

> Legend: ✅ done · 🔧 code task · 👤 keeper task · ⚠️ known gap

---

## Status

**Phases 1–4 complete.** The dispatch core, task lifecycle, and audit layer are all implemented. The system is ready for a smoke test on the hall repo itself before the webhook relay is built.

---

## What was built

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

### 🔧 FR-9: Automatic routing (cap → least-used agent)

Currently when an agent exceeds its weekly cap the Hall posts a comment and exits. The design calls for rerouting to the least-used eligible agent with matching capabilities.

What needs to happen in `invoke.yml` dispatch job:
1. After cap check fires, query the counter cache for all agents
2. Filter by `capabilities` overlap with the requested agent (from `agents.yml`)
3. Pick the agent with the lowest count that is still under its own cap
4. Re-run auth + dispatch with the alternate agent
5. Post a comment noting the reroute (`rerouted: true` in audit log)

`routing.yml` `strategy: least_used` and `fallback: queue` are already parsed — implement the lookup and fallback to `hall:queued` label when all alternates are also capped.

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
