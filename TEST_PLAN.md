# Hall of Automata — Test Plan

Manual end-to-end test plan. No automated test runner — every case requires a live GitHub environment with the App installed and correct environments provisioned.

Cases marked ★ must be re-run after any change to `invoke.yml`, `hall-ci-loop.yml`, `hall-cleanup.yml`, or anything under `scripts/` or `actions/`.

---

## Prerequisites

### Phase A

| Requirement | Detail |
|-------------|--------|
| GitHub App installed | `hall-of-automata` installed on MockaSort-Studio org |
| App secrets | `APP_ID` and `APP_PRIVATE_KEY` set in hall repo secrets |
| Labels | `hall:onboard-invoker`, `hall:onboard-automaton`, `hall:active-invoker`, `hall:awaiting-input`, `hall:queued`, `hall:invoker-queued` all created |
| Test invoker account | A GitHub account not yet registered |
| Unauthorized account | A GitHub account NOT in `automata-invokers` |

### Phase B

Produced by Phase A — do not create manually.

| Requirement | Detail |
|-------------|--------|
| Registered invoker | TC-INV-03 completed; `hall:active-invoker` applied |
| `invoker/<handle>` environment | Holds `CLAUDE_CODE_OAUTH_TOKEN`, `HALL_USAGE_COUNT`, `HALL_WEEKLY_CAP` |
| Agents in `agents.yml` | `hamlet`, `mergio` present on `main` |
| Target repo | Any repo in the org where the App is installed |

---

## Phase A — Onboarding

### TC-INV-01 ★ — Environment provisioned on label

**Trigger:** Open a `New Invoker` issue via issue template (auto-applies `hall:onboard-invoker`).

**Expected:**
- `onboard-invoker.yml` fires; `invoker/<handle>` environment created
- `HALL_WEEKLY_CAP` set (hours × 3)
- Bot posts comment with environment settings link and token instructions

**Verify:** environment exists in repo Settings; `HALL_WEEKLY_CAP` variable set; comment present.

> **Status: ✅ Pass**

---

### TC-INV-02 — Secret check gates test-token job

**Precondition:** TC-INV-01 complete; `CLAUDE_CODE_OAUTH_TOKEN` NOT yet added.

**Trigger:** Reply `ready` on the onboarding issue.

**Expected:** secret slot not found → retry prompt posted; `test-token` job does NOT run.

**Verify:** retry comment on issue; no `test-token` run in Actions.

> **Status: ✅ Pass**

---

### TC-INV-03 ★ — Successful token validation and finalization

**Precondition:** TC-INV-01 complete; valid `CLAUDE_CODE_OAUTH_TOKEN` added to `invoker/<handle>`.

**Trigger:** Reply `ready` on the onboarding issue.

**Expected:**
- Curl probe returns HTTP 200; `test-token` passes
- Welcome comment posted; `hall:active-invoker` applied; issue closed

**Verify:** issue closed; `hall:active-invoker` present; welcome comment posted.

> **Status: ✅ Pass**

---

### TC-INV-04 — Bad token and quota-exhausted edge cases

**Bad token:** Add an invalid value as `CLAUDE_CODE_OAUTH_TOKEN`. Reply `ready`. Expected: HTTP 401/403; retry prompt posted; issue stays open; no `hall:active-invoker`.

**Quota exhausted (HTTP 429):** Add a valid token whose quota is at zero. Reply `ready`. Expected: `hall:active-invoker` AND `hall:invoker-queued` applied; queued message posted (not retry prompt); issue closed.

**Verify:** respectively — retry comment, no label; or both labels + closed issue.

> **Status: ✅ Pass**

---

### TC-AUT-01 ★ — Automaton onboarding: full provisioning

**Trigger:** Open a `New Automaton` issue via template with a complete, valid character sheet (slug, display_name, invoker, character, domains, scope, scope_summary). Template auto-applies `hall:onboard-automaton`.

**Expected:**
- `onboard-automaton.yml` fires; `select-invoker` pool-selects invoker; `analyze` job runs
- Old Major evaluates the sheet; all fields pass
- Old Major opens PR on branch `hall/old-major/issue-{N}` containing `roster/<slug>.md` and updated `agents.yml`
- Provisioning summary comment posted; issue closed

**Verify:** PR exists on the correct branch with both files; issue closed; no `hall:awaiting-input` label.

> **Status: ✅ Pass**

---

### TC-AUT-02 — Automaton onboarding: clarification loop

**Trigger:** Open a `New Automaton` issue with an incomplete sheet (missing `scope_summary`, placeholder domains).

**Expected (initial):** Old Major identifies gaps; comment posted; `hall:awaiting-input` applied; no PR opened.

**Trigger (reply):** Reply with a corrected sheet that still leaves one field missing.

**Expected (re-analyze):** gaps remain; updated comment posted; `hall:awaiting-input` stays; no PR.

**Trigger (reply):** Reply with a fully corrected sheet.

**Expected (pass):** `hall:awaiting-input` removed; PR opened as in TC-AUT-01.

**Verify at each step:** `hall:awaiting-input` label matches expectation; no PR until full pass.

> **Status: ✅ Pass**

---

## Phase B — Task Dispatch

### TC-01 ★ — Label trigger, authorized invoker

**Trigger:** Apply `hall:hamlet` to an issue with a clear, self-contained task.

**Expected:**
- `detect` resolves agent as `hamlet`; status card appears (`Dispatching agent…`)
- Agent opens PR on branch `hall/hamlet/issue-{N}`; status card → `PR opened — #M`
- `hall:hamlet` applied to PR; audit artifact present; counter incremented by 1

**Verify:** status card stage is `PR opened`; PR labeled; artifact in Actions → Artifacts.

> **Status: ✅ Pass**

---

### TC-02 ★ — Comment trigger (`@mention`)

**Trigger:** Post `@hall-of-automata[bot] hamlet` as a comment on an open issue.

**Expected:** same as TC-01; audit log trigger-event is `issue_comment`.

> **Status: ✅ Pass**

---

### TC-03 ★ — Unauthorized invoker

**Trigger:** Apply `hall:hamlet` label or post `@mention` as a user NOT in `automata-invokers`.

**Expected:** rejection comment posted; label removed (label trigger); no PR; no status card; counter unchanged.

**Verify:** no status card; no PR; label removed; counter value unchanged.

> **Status: ✅ Pass**

---

### TC-04 — Pool cap exceeded

**Setup:** Lower `HALL_WEEKLY_CAP` to 1; dispatch once so `HALL_USAGE_COUNT` reaches 1.

**Trigger:** Attempt a second dispatch.

**Expected:** `notify-queued` fires; cap-exceeded comment posted; `hall:invoker-queued` applied; no agent run.

**Verify:** `hall:invoker-queued` present; no new PR. Restore cap and zero counter after test.

> **Status: ✅ Pass**

---

### TC-05 ★ — Awaiting-input state

**Trigger:** Apply `hall:hamlet` to an intentionally vague issue ("Implement the thing we discussed.").

**Expected:** agent posts a clarifying question; no PR opened; status card → `Awaiting context`; `hall:awaiting-input` applied.

**Verify:** both label and status card stage set correctly; no PR.

> **Status: ✅ Pass**

---

### TC-05b ★ — Advising and researching modes

**Advising:** Issue `### Mode` = `Advising`. Apply `hall:{agent}`. Expected: agent posts analysis comment, no PR; `stage=done`; issue closed; no `hall:awaiting-input`.

**Researching:** Same setup with `### Mode` = `Researching`. Expected: same outcome — findings comment, no PR, closed, `stage=done`.

**Verify both:** issue closed; status card `Done — response posted`; no `hall:awaiting-input`.

> **Status: ✅ Pass**

---

### TC-06 — Human reply → awaiting-input re-dispatch

**Precondition:** TC-05 complete; issue has `hall:awaiting-input` + `hall:hamlet`.

**Trigger:** Post a plain comment (not `@mention`) as an authorized team member.

**Expected:** path B fires; agent re-dispatched; `hall:awaiting-input` removed; PR opened; status card → `PR opened`.

**Verify:** label gone; PR exists.

> **Status: ✅ Pass**

---

### TC-07 ★ — PR review → re-dispatch

**Precondition:** Agent PR exists with `hall:hamlet` label.

**Trigger:** Submit PR review with `@hall-of-automata[bot] hamlet` in review body, requesting changes.

**Expected:** `pull_request_review` fires; task memory restored; agent pushes corrective commits to same branch; status card → `PR opened`.

**Verify:** new commits on same branch; PR not closed.

> **Status: ✅ Pass**

---

### TC-08 ★ — CI failure → re-dispatch loop

**Precondition:** Agent PR exists; CI workflow configured to fail on the branch.

**Trigger:** CI failure on `hall/*` branch.

**Expected:** `hall-ci-loop.yml` fires; `retry_count` = 0; status card → `CI fix in progress (attempt 1 of 3)`; agent re-dispatched with failure context; new commits pushed.

**Verify:** status card shows CI fix stage; `retry_count` = 1 in next memory JSON.

> **Status: ✅ Pass**

---

### TC-09 — CI escalation

**Precondition:** `retry_count` ≥ `max_retries` for the agent (2 for hamlet/mergio).

**Trigger:** Another CI failure on the same branch.

**Expected:** `escalate=true`; PR comment mentions `@mksetaro`; status card → `Escalated — keeper notified`; no re-dispatch.

**Verify:** escalation comment present; no new agent run.

> **Status: ✅ Pass**

---

### TC-10 ★ — PR merged → cleanup

**Precondition:** Agent PR with `hall:hamlet` label; linked to issue via `closes #N`.

**Trigger:** Merge the PR.

**Expected:** `hall:hamlet` label removed from PR; task memory cache deleted; summary comment posted on issue #N; stale labels cleaned.

**Verify:** PR unlabeled; issue has summary comment; no stale `hall:awaiting-input`.

> **Status: ✅ Pass**

---

### TC-11 — PR closed without merge → cleanup

**Trigger:** Close agent PR without merging.

**Expected:** label removed; memory cache deleted; NO summary comment on linked issue.

**Verify:** PR unlabeled; no summary comment.

> **Status: ✅ Pass**

---

### TC-12 — Counter persistence and weekly reset

**Steps:** Run TC-01 twice; verify `HALL_USAGE_COUNT` increments. Trigger `weekly-reset.yml`; verify count resets to 0 before next dispatch.

**Verify:** audit artifacts show correct `weekly_count_after`; env var reads 0 after reset.

> **Status: ✅ Pass**

---

### TC-13 — Task memory save and restore

**Steps:** Run TC-01; note PR number. Trigger a CI failure (TC-08). Verify memory is restored and `retry_count` incremented.

**Verify:** audit artifact for CI re-dispatch shows correct retry count; status card shows `attempt 1 of 3`.

> **Status: ✅ Pass**

---

### TC-14 — Bot comment does not re-dispatch

**Precondition:** Issue has `hall:awaiting-input` + `hall:hamlet`.

**Trigger:** Post a comment as `github-actions[bot]` or another bot.

**Expected:** no dispatch — path B guard filters bot actors.

**Verify:** no dispatch job triggered.

> **Status: ✅ Pass**

---

### TC-15 — System labels do not act as bound agent

**Precondition:** Issue has `hall:awaiting-input` + `hall:queued` (or `hall:invoker-queued`); NO `hall:{agent}` label.

**Trigger:** Post a human comment.

**Expected:** path B finds no bound agent label; no dispatch.

**Verify:** no dispatch job run.

> **Status: ✅ Pass**

---

## Release Checklist

Run before any release tag. All items must pass.

- [x] TC-INV-01 — environment provisioned on label
- [x] TC-INV-03 — successful token validation and finalization
- [x] TC-AUT-01 — automaton onboarding: full provisioning
- [x] TC-01 — label trigger, authorized
- [x] TC-02 — comment trigger, authorized
- [x] TC-03 — unauthorized invoker (label and comment)
- [x] TC-05 — awaiting-input state set correctly
- [x] TC-05b — advising / researching modes: done, closed
- [x] TC-06 — human reply re-dispatches
- [x] TC-07 — PR review re-dispatch
- [x] TC-08 — CI failure re-dispatch (at least 1 cycle)
- [x] TC-10 — PR merged, cleanup complete
- [x] TC-11 — PR closed (not merged), no summary comment
- [x] TC-14 — bot comment does not re-dispatch
- [x] TC-15 — system label does not act as bound agent

**Run after routing change:** TC-04 (cap exceeded).
**Run after memory change:** TC-13, TC-09 (escalation).
**Run after cleanup change:** TC-10, TC-11.

---

## Regression Triggers

| Change area | Re-run |
|-------------|--------|
| `detect-invoke-context.js` | 01, 02, 03, 05b, 06, 14, 15 |
| `invoke.yml` dispatch job | 01, 02, 05, 05b, 06, 07 |
| `hall-ci-loop.yml` | 08, 09 |
| `hall-cleanup.yml` / `actions/cleanup` | 10, 11 |
| `actions/authorize` | 03 |
| `actions/counter` | 04, 12 |
| `actions/memory` | 08, 13 |
| `actions/status-card` | 01, 05, 05b, 08, 09, 10 |
| `scripts/*.sh` or `scripts/*.js` | All ★ cases |
