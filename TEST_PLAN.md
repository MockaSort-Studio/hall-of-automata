# Hall of Automata — Test Plan

Manual end-to-end test plan. No automated test runner exists — every case requires a real GitHub environment with the App installed, the `hall/hamlet` Environment configured, and at least one target repo available.

Run through **all cases in the Release Checklist** before tagging a release. After any change to `invoke.yml`, `hall-ci-loop.yml`, `hall-cleanup.yml`, or the `scripts/` or `actions/` directories, run the cases marked with ★.

---

## Environment setup

| Requirement | Detail |
|-------------|--------|
| GitHub App installed | `hall-of-automata` installed on MockaSort-Studio org |
| App secrets | `APP_ID` and `APP_PRIVATE_KEY` set in hall repo secrets |
| Agent environment | `hall/hamlet` GitHub Environment exists with `CLAUDE_CODE_OAUTH_TOKEN` |
| Invoker team | Test user is a member of `automata-invokers` |
| Unauthorized user | A second account that is NOT in `automata-invokers` |
| Target repo | Any repo in the org where the App is installed |

---

## TC-01 ★ — Label trigger, authorized invoker

**Trigger:** Apply label `hall:hamlet` to an issue on the hall repo (or a target repo once relay is live).

**Steps:**
1. Create a simple, self-contained issue: "Add a greeting function to scripts/hello.sh"
2. Apply label `hall:hamlet`

**Expected:**
- `invoke.yml` detect job runs; agent is resolved as `hamlet`
- dispatch job: status card comment appears on the issue with stage `Dispatching agent...`
- Agent runs; opens PR on branch `hall/hamlet/issue-{N}` with minimal implementation
- Status card updates to `PR opened — #M`
- `hall:hamlet` label applied to the opened PR
- Audit artifact `hall-log-hamlet-{N}-{run_id}` visible in Actions → Artifacts
- Weekly counter incremented by 1

**Verify:**
- Issue has `<!-- hall-status -->` comment, stage is `PR opened`
- PR exists, labeled `hall:hamlet`, branch matches `hall/hamlet/issue-{N}`
- Actions → Artifacts: log JSON present and parseable

---

## TC-02 ★ — Comment trigger (`@mention`), authorized invoker

**Trigger:** Post `@hall-of-automata[bot] hamlet` as a comment on an open issue.

**Steps:**
1. Open an issue with a clear, small task
2. Comment: `@hall-of-automata[bot] hamlet`

**Expected:** same as TC-01.

**Verify:** same as TC-01 plus confirm trigger-event in audit log is `issue_comment`.

---

## TC-03 ★ — Unauthorized invoker

**Trigger:** Apply `hall:hamlet` label or post `@hall-of-automata[bot] hamlet` as a user NOT in `automata-invokers`.

**Expected:**
- Label trigger: label is removed from the issue; rejection comment posted by `hall-of-automata[bot]`
- Comment trigger: rejection comment posted; no dispatch
- No PR opened; no status card; counter NOT incremented

**Verify:** issue has no status card; no PR; confirm label was removed (label trigger only); counter value unchanged.

---

## TC-04 — Cap exceeded

**Precondition:** Set `hamlet.weekly_cap` in `routing.yml` to 1 and dispatch once successfully first.

**Trigger:** Attempt a second dispatch (any method).

**Expected:**
- Cap-exceeded comment posted: "hamlet has reached its weekly invocation cap (1). The request has been queued."
- No agent run; counter NOT incremented beyond cap

**Verify:** issue has cap-exceeded comment; no new PR; restore `routing.yml` after test.

---

## TC-05 ★ — Awaiting-input state

**Precondition:** Craft an issue that is intentionally vague enough that the agent will ask a clarifying question rather than open a PR. Example: "Implement the thing we discussed."

**Trigger:** Apply `hall:hamlet` label or post `@mention`.

**Expected:**
- Agent runs, posts a question comment, does NOT open a PR
- Status card updates to `Awaiting context — question posted`
- Label `hall:awaiting-input` applied to the issue
- No PR; no `hall:hamlet` label on any PR

**Verify:** issue has both `hall:awaiting-input` label and status card in `awaiting-input` stage.

---

## TC-06 — Human reply → awaiting-input re-dispatch

**Precondition:** TC-05 completed successfully; issue has `hall:awaiting-input` + `hall:hamlet` labels.

**Trigger:** Post any plain comment (NOT an `@mention`) on the issue as an authorized team member.

**Expected:**
- `invoke.yml` fires (issue_comment event, path B)
- Agent re-dispatched with full thread as context
- `hall:awaiting-input` label removed from issue
- Agent now opens a PR (assuming reply provided sufficient context)
- Status card → `PR opened`

**Verify:** `hall:awaiting-input` label gone from issue; PR exists.

---

## TC-07 ★ — PR review → re-dispatch

**Precondition:** Agent has opened a PR (from TC-01 or TC-02); PR has `hall:hamlet` label.

**Trigger:** Submit a PR review with body containing `@hall-of-automata[bot] hamlet — please address the comment below` and request changes.

**Steps:**
1. On the agent's PR, start a review
2. Include `@hall-of-automata[bot] hamlet` in the review summary body
3. Submit with "Request changes"

**Expected:**
- `invoke.yml` fires (pull_request_review event)
- Task memory restored from cache
- Review context appended to CLAUDE.md
- Agent re-dispatched, pushes corrective commits to the same branch
- Status card → `PR opened` (same PR)

**Verify:** new commits appear on the same branch; PR not closed; no new PR opened.

---

## TC-08 ★ — CI failure → re-dispatch loop

**Precondition:** Agent has opened a PR. The target repo has a CI workflow that can be made to fail (e.g., add a failing test or lint rule to the branch before the agent touches it).

**Trigger:** Push or merge a commit to the agent's branch that causes CI to fail, OR set up the repo so the agent's initial commit fails CI naturally.

**Expected:**
- `hall-ci-loop.yml` detect job fires on `check_suite: completed` with `conclusion: failure`
- Branch matches `hall/*`; PR has `hall:hamlet` label
- Task memory restored; `retry_count` is 0
- `escalate=false`; status card → `CI fix in progress (attempt 1 of 3)`
- Agent re-dispatched with CI failure context
- After fix push, CI runs again

**Verify:** status card shows CI fix stage; new commits pushed by agent; `retry_count` in memory JSON is 1 after re-dispatch.

---

## TC-09 — CI escalation

**Precondition:** Task memory for the PR has `retry_count` ≥ `max_retries` (3 by default). Force this by manually editing the memory cache or running TC-08 enough times.

**Trigger:** Another CI failure on the same branch.

**Expected:**
- `resolve-retry.sh` outputs `escalate=true`
- Keeper (`@mksetaro`) mentioned in a PR comment: "retries exhausted after N attempts. Last CI failures: ... Manual review required."
- Status card → `Escalated — keeper notified`
- Agent NOT re-dispatched

**Verify:** PR has escalation comment with `@mksetaro` mention; status card shows escalated; no new agent run.

---

## TC-10 ★ — PR merged → cleanup

**Precondition:** Agent PR exists with `hall:hamlet` label, linked to an issue via `closes #N` in the PR body.

**Trigger:** Merge the PR.

**Expected:**
- `hall-cleanup.yml` fires (pull_request: closed, merged=true)
- `hall:hamlet` label removed from the PR
- Task memory cache entry deleted (verify via Actions → Caches if visible, or by triggering a re-dispatch and observing cache miss)
- Summary comment posted on linked issue #N: "hamlet — PR #M merged. Task complete."
- `hall:awaiting-input` label removed from issue #N (if present)

**Verify:** PR has no `hall:hamlet` label; issue #N has summary comment; no stale labels.

---

## TC-11 — PR closed without merge → cleanup

**Precondition:** Agent PR exists with `hall:hamlet` label, linked to an issue.

**Trigger:** Close the PR without merging.

**Expected:**
- `hall:hamlet` label removed from PR
- Task memory cache deleted
- No summary comment on the linked issue (merged=false)
- `hall:awaiting-input` label removed from issue (if present)

**Verify:** PR has no label; no summary comment on issue.

---

## TC-12 — Weekly counter persistence and reset

**Steps:**
1. Run TC-01 twice in the same week; note the `weekly-count-after` field in the audit artifact
2. After the week rolls over (or manually change the cache key date), run again

**Expected:**
- Count increments 1 → 2 within the same week
- After week rollover, count resets to 1

**Verify:** audit artifacts show correct `weekly_count_after` values.

---

## TC-13 — Task memory save and restore

**Steps:**
1. Run TC-01 → note the PR number (e.g. #58)
2. Trigger a CI failure (TC-08) — memory should be restored and `retry_count` incremented

**Expected:**
- After initial dispatch, `hall-task-{repo}-58` cache entry exists
- After CI re-dispatch, memory JSON shows `retry_count: 1`

**Verify:** audit artifact for the CI re-dispatch shows the correct retry count; status card shows `attempt 1 of 3`.

---

## TC-14 — Bot comment does not re-dispatch (path B guard)

**Precondition:** Issue has `hall:awaiting-input` + `hall:hamlet` labels.

**Trigger:** Post a comment as `github-actions[bot]` or another bot account.

**Expected:** `invoke.yml` does NOT fire (or fires and immediately exits — `agent` output is empty). No re-dispatch.

**Verify:** no new workflow run dispatched, or if workflow runs, it produces no dispatch job.

---

## TC-15 — hall:queued label does not trigger dispatch (path B guard)

**Precondition:** Issue has `hall:awaiting-input` + `hall:queued` labels but NO `hall:{agent}` label.

**Trigger:** Post a human comment on the issue.

**Expected:** path B finds no bound agent label (after excluding system labels); no dispatch.

**Verify:** no dispatch job run.

---

## Release Checklist

Run before any release tag. All items must pass.

- [ ] TC-01 — label trigger, authorized
- [ ] TC-02 — comment trigger, authorized
- [ ] TC-03 — unauthorized invoker (both label and comment)
- [ ] TC-05 — awaiting-input state set correctly
- [ ] TC-06 — human reply re-dispatches
- [ ] TC-07 — PR review re-dispatch
- [ ] TC-08 — CI failure re-dispatch (at least 1 cycle)
- [ ] TC-10 — PR merged, cleanup complete, no stale labels
- [ ] TC-11 — PR closed (not merged), no summary comment
- [ ] TC-14 — bot comment does not re-dispatch
- [ ] TC-15 — hall:queued does not act as bound agent

**Run after any routing change:** TC-04 (cap exceeded).
**Run after any memory change:** TC-13 (memory save/restore), TC-09 (escalation).
**Run after any cleanup change:** TC-10, TC-11.

---

## Regression triggers

| Change area | Re-run these TCs |
|-------------|-----------------|
| `detect-invoke-context.js` | 01, 02, 03, 06, 14, 15 |
| `invoke.yml` dispatch job | 01, 02, 05, 06, 07 |
| `hall-ci-loop.yml` | 08, 09 |
| `hall-cleanup.yml` / `actions/cleanup` | 10, 11 |
| `actions/authorize` | 03 |
| `actions/counter` | 04, 12 |
| `actions/memory` | 08, 13 |
| `actions/status-card` | 01, 05, 08, 09, 10 |
| `scripts/*.sh` or `scripts/*.js` | All ★ cases |
