# Hall of Automata — Test Plan

Manual end-to-end test plan. No automated test runner exists — every case requires a real GitHub environment with the App installed and the correct environments provisioned.

Run through all cases in **Phase A** before any other phase. Cases marked ★ must be re-run after any change to `invoke.yml`, `hall-ci-loop.yml`, `hall-cleanup.yml`, or anything under `scripts/` or `actions/`.

---

## Environment setup — Phase A (onboarding prerequisites)

These must exist before running any Phase A test. Create them manually in repo Settings → Environments.

| Requirement | Detail |
|-------------|--------|
| GitHub App installed | `hall-of-automata` installed on MockaSort-Studio org |
| App secrets | `APP_ID` and `APP_PRIVATE_KEY` set in hall repo secrets |
| `hall/roster` environment | Exists; initial inactive deployment seeded (`gh api repos/{owner}/{repo}/deployments -f ref=main -f environment=hall/roster -f description="Roster seed" -f auto_merge=false -F required_contexts=[]`) — or run `bash scripts/bootstrap-old-major.sh` |
| At least one registered invoker | `invoker/<handle>` environment with `CLAUDE_CODE_OAUTH_TOKEN` — automaton onboarding uses the invoker pool; run TC-INV-01/03 first |
| Labels | `hall:onboard-invoker`, `hall:onboard-automaton`, `hall:active-invoker`, `hall:awaiting-input`, `hall:queued`, `hall:invoker-queued` all created in the repo |
| GitHub App permissions | `environments: write`, `deployments: write`, `contents: write`, `issues: write` |
| Test invoker account | A GitHub account not yet registered as an invoker |
| Unauthorized account | A GitHub account that is NOT in `automata-invokers` |

## Environment setup — Phase B (task dispatch prerequisites)

Run after Phase A completes. These are produced by Phase A — do not create them manually.

| Requirement | Detail |
|-------------|--------|
| Registered invoker | At least one account completed Phase A TC-INV-03 successfully (`hall:active-invoker` applied) |
| `invoker/<handle>` environment | Created by onboarding; holds `CLAUDE_CODE_OAUTH_TOKEN`, `HALL_USAGE_COUNT`, `HALL_WEEKLY_CAP` |
| Agent in `agents.yml` | `hamlet` or `mergio` entry present on `main` (both are — no separate env required) |
| Roster persona file | `roster/hamlet.md` or `roster/mergio.md` present on `main` (both are) |
| Target repo | Any repo in the org where the App is installed (hall repo itself is fine) |
| Unauthorized user | A second GitHub account NOT in `automata-invokers` |

---

## Phase A — Onboarding

### TC-INV-01 — Invoker onboarding: environment provisioned on label

**Trigger:** Open a `New Invoker` issue using the issue template (fills `hall:onboard-invoker` automatically).

**Steps:**
1. Open the issue template, enter a GitHub handle and a weekly cap in hours
2. Submit — template auto-applies `hall:onboard-invoker`

**Expected:**
- `onboard-invoker.yml` fires (labeled trigger); `setup` job runs with **no declared environment** (uses repo-level app secrets only)
- `invoker/<handle>` GitHub Environment is created
- `HALL_WEEKLY_CAP` variable set (hours × 3)
- Old Major posts a comment with a direct link to the environment settings page and instructions to add `CLAUDE_CODE_OAUTH_TOKEN`

**Verify:**
- Repo Settings → Environments: `invoker/<handle>` exists
- `HALL_WEEKLY_CAP` variable is present with correct value
- Issue has a comment from `hall-of-automata[bot]` with an environment link

---

### TC-INV-02 — Invoker onboarding: secret check gates test-token job

**Precondition:** TC-INV-01 complete. Do NOT add `CLAUDE_CODE_OAUTH_TOKEN` yet.

**Trigger:** Reply `ready` on the onboarding issue.

**Expected:**
- `parse-ready` job fires; `verify-invoker-setup.js` checks the secret slot
- Secret not found → Old Major posts a retry prompt telling the invoker to add the secret first
- `test-token` job does NOT run

**Verify:** issue has a "secret not found" comment; no `test-token` run visible in Actions for this trigger.

---

### TC-INV-03 ★ — Invoker onboarding: successful token validation and finalization

**Precondition:** TC-INV-01 complete. Add a valid `CLAUDE_CODE_OAUTH_TOKEN` to `invoker/<handle>`.

**Trigger:** Reply `ready` on the onboarding issue.

**Expected:**
- `parse-ready` fires; secret slot found → `test-token` job runs in `invoker/<handle>` env
- Curl probe to `api.anthropic.com` returns HTTP 200; `test-passed=true`, `quota-exceeded=false`
- `finalize` job runs: welcome comment posted, `hall:active-invoker` label applied, issue closed

**Verify:**
- Issue has welcome comment ("multiclassed — invoker")
- Issue is closed
- `hall:active-invoker` label on the issue

---

### TC-INV-04 — Invoker onboarding: bad token produces retry prompt

**Precondition:** TC-INV-01 complete. Add an intentionally invalid value as `CLAUDE_CODE_OAUTH_TOKEN` (e.g., the string `invalid`).

**Trigger:** Reply `ready` on the onboarding issue.

**Expected:**
- `test-token` job runs; curl probe returns HTTP 401 or 403; `test-passed=false`
- `finalize` posts retry prompt: token invalid, re-run `claude setup-token` and update the secret
- Issue remains open; `hall:active-invoker` NOT applied

**Verify:** issue has retry comment; issue open; no `hall:active-invoker` label.

---

### TC-INV-05 — Invoker onboarding: valid token, quota exhausted → queued

**Precondition:** TC-INV-01 complete. Add a valid `CLAUDE_CODE_OAUTH_TOKEN` whose Anthropic quota is currently at zero (429 response).

**Trigger:** Reply `ready` on the onboarding issue.

**Expected:**
- `test-token` job runs; curl probe returns HTTP 429; `test-passed=true`, `quota-exceeded=true`
- `finalize` job: `hall:active-invoker` AND `hall:invoker-queued` labels applied
- "Queued" comment posted (not the full welcome); issue closed
- No retry prompt — token is valid

**Verify:**
- Issue is closed
- Both `hall:active-invoker` and `hall:invoker-queued` labels present
- Comment says invoker is queued until Monday reset, not that the token is invalid

---

### TC-AUT-01 ★ — Automaton onboarding: character sheet passes, full provisioning

**Trigger:** Open a `New Automaton` issue using the issue template; fill a complete, valid character sheet (slug, display_name, invoker, character, domains, scope, scope_summary all present and coherent). Template auto-applies `hall:onboard-automaton`.

**Expected:**
- `onboard-automaton.yml` fires; `select-invoker` job pool-selects least-used invoker; `analyze` job runs in `invoker/<handle>` env
- Old Major evaluates the sheet; all fields pass
- Persona gist created (public or secret)
- `hall/<slug>` GitHub Environment created
- Roster gist updated via `hall/roster` deployment payload with new catalog entry
- Provisioning summary comment posted; issue closed

**Verify:**
- Repo Settings → Environments: `hall/<slug>` exists
- `hall/roster` environment has an updated deployment
- Gist URL referenced in the summary comment is accessible
- Issue is closed; no `hall:awaiting-input` label

---

### TC-AUT-02 — Automaton onboarding: incomplete sheet → clarifying questions

**Trigger:** Open a `New Automaton` issue with a character sheet missing required fields (e.g., no `scope_summary`, placeholder `domains`).

**Expected:**
- `analyze` job runs; Old Major identifies the gaps
- Comment posted listing exactly what needs fixing
- `hall:awaiting-input` label applied to the issue
- No gist created; no environment created; no roster update

**Verify:**
- Issue has clarifying-questions comment
- `hall:awaiting-input` label present
- No new environment in Settings

---

### TC-AUT-03 — Automaton onboarding: invoker addresses feedback, provisioning completes

**Precondition:** TC-AUT-02 complete; issue has `hall:onboard-automaton` + `hall:awaiting-input`.

**Trigger:** Reply on the issue with the corrected character sheet fields.

**Expected:**
- `re-analyze` job fires (issue_comment trigger with both labels present)
- Old Major re-evaluates; sheet now passes
- `hall:awaiting-input` label removed
- Full provisioning proceeds (gist, environment, roster, summary comment, close)

**Verify:** same as TC-AUT-01 verify; `hall:awaiting-input` gone.

---

### TC-AUT-04 — Automaton onboarding: re-analyze still finds gaps

**Precondition:** TC-AUT-02 complete.

**Trigger:** Reply with a correction that still leaves a required field missing.

**Expected:**
- `re-analyze` runs; gaps remain
- Updated clarifying comment posted
- `hall:awaiting-input` label stays
- No provisioning

**Verify:** issue still has `hall:awaiting-input`; no new environment.

---

## Phase B — Task dispatch

### TC-01 ★ — Label trigger, authorized invoker

**Precondition:** Phase A complete; `hamlet` entry present in `agents.yml` on main; test invoker is `hall:active-invoker`.

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

**Precondition:** Lower `HALL_WEEKLY_CAP` on `invoker/<handle>` to 1 via repo Settings → Environments. Dispatch once successfully first so `HALL_USAGE_COUNT` reaches 1.

**Trigger:** Attempt a second dispatch (any method).

**Expected:**
- Pool selection finds no under-cap invoker; `notify-queued` job fires
- Cap-exceeded comment posted on the issue; `hall:invoker-queued` label applied
- No agent run; counter NOT incremented

**Verify:** issue has cap-exceeded comment; `hall:invoker-queued` label present; no new PR. Restore `HALL_WEEKLY_CAP` and zero `HALL_USAGE_COUNT` after test.

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

## TC-05b — Advising mode: response posted, issue closed

**Precondition:** Registered invoker; any issue.

**Trigger:** Apply `hall:hamlet` (or `hall:old-major`) to an issue whose `### Mode` field reads `Advising — evaluate options and recommend`.

**Steps:**
1. Create an issue with `### Mode` set to `Advising — evaluate options and recommend`
2. Apply a `hall:{agent}` label

**Expected:**
- `detect` job parses `mode=advising` and surfaces it as a job output
- Agent runs; posts a comment with options, tradeoffs, and a recommendation; does NOT open a PR
- `resolve-final-stage.sh` sees `MODE=advising` + no PR → `stage=done`
- Status card updates to `Done — response posted`
- Issue is closed by the post-dispatch close step
- `hall:awaiting-input` label is NOT applied

**Verify:**
- Issue is closed
- Status card shows `Done — response posted`
- No PR opened; no `hall:awaiting-input` label

---

## TC-05c — Researching mode: response posted, issue closed

**Precondition:** Registered invoker; any issue.

**Trigger:** Apply `hall:{agent}` label to an issue whose `### Mode` field reads `Researching — investigate and report`.

**Steps:**
1. Create an issue with `### Mode` set to `Researching — investigate and report`
2. Apply a `hall:{agent}` label

**Expected:**
- `detect` job parses `mode=researching`
- Agent runs; posts findings comment; does NOT open a PR
- `resolve-final-stage.sh` sees `MODE=researching` + no PR → `stage=done`
- Status card updates to `Done — response posted`
- Issue is closed
- `hall:awaiting-input` label is NOT applied

**Verify:**
- Issue is closed
- Status card shows `Done — response posted`
- No PR opened; no `hall:awaiting-input` label

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

**Precondition:** Task memory for the PR has `retry_count` ≥ `max_retries` (2 for hamlet/mergio). Force this by running TC-08 enough times or manually patching the memory cache entry.

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
2. Manually trigger the `weekly-reset.yml` scheduled workflow (or wait for Monday 00:00 UTC), then run TC-01 again

**Expected:**
- Count increments 1 → 2 within the same week (visible in `invoker/<handle>` env variable `HALL_USAGE_COUNT`)
- After reset, `HALL_USAGE_COUNT` in the `invoker/<handle>` env reads 0 before the next dispatch

**Verify:** audit artifacts show correct `weekly_count_after` values; `invoker/<handle>` env variable is 0 after reset.

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

## TC-15 — hall:queued / hall:invoker-queued labels do not trigger dispatch

**Precondition:** Issue has `hall:awaiting-input` + `hall:queued` (or `hall:invoker-queued`) labels but NO `hall:{agent}` label.

**Trigger:** Post a human comment on the issue.

**Expected:** path B finds no bound agent label (after excluding all system labels including `hall:queued` and `hall:invoker-queued`); no dispatch.

**Verify:** no dispatch job run for either system label.

---

## Release Checklist

Run before any release tag. All items must pass.

- [ ] TC-01 — label trigger, authorized
- [ ] TC-02 — comment trigger, authorized
- [ ] TC-03 — unauthorized invoker (both label and comment)
- [ ] TC-05 — awaiting-input state set correctly
- [ ] TC-05b — advising mode: Done — response posted, issue closed
- [ ] TC-05c — researching mode: Done — response posted, issue closed
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
| `detect-invoke-context.js` | 01, 02, 03, 05b, 05c, 06, 14, 15 |
| `invoke.yml` dispatch job | 01, 02, 05, 05b, 05c, 06, 07 |
| `hall-ci-loop.yml` | 08, 09 |
| `hall-cleanup.yml` / `actions/cleanup` | 10, 11 |
| `actions/authorize` | 03 |
| `actions/counter` | 04, 12 |
| `actions/memory` | 08, 13 |
| `actions/status-card` | 01, 05, 05b, 05c, 08, 09, 10 |
| `scripts/*.sh` or `scripts/*.js` | All ★ cases |
