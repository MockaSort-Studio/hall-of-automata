---
icon: material/refresh
---

# CI Loop and PR Checks

How Hall workflows interact with GitHub's check system, why they appear as PR checks, and why that is intentional.

---

## Two distinct check-producing mechanisms

### 1. Target-repo CI — the deliberate signal

`hall-ci-loop.yml` triggers on `check_suite: [completed]`. This is not incidental — it is the load-bearing mechanism of the agentic CI fix loop.

```
CI fails on hall/<agent>/issue-N branch
  └─ GitHub emits check_suite.completed event
       └─ hall-ci-loop.yml fires
            └─ detect-ci-context.js reads the event
                 └─ filters: suite.conclusion == 'failure'
                             suite.head_branch.startsWith('hall/')
                      └─ re-dispatches agent to fix failures
```

Without this model, fixing CI failures would require polling or an external webhook. The `check_suite.completed` event is the platform's native, push-based signal for "CI just finished on a commit." It requires zero cooperation from target repositories — Hall does not need to know what CI workflows they run, only that something failed.

**Verdict: intentional, keep it.**

### 2. Dispatch workflow runs — a side effect

`invoke.yml` triggers on `pull_request_review: [submitted]`. GitHub automatically associates any workflow run triggered by a PR-related event with that PR as a check run. The `detect` and `dispatch` jobs surface in the PR's **Checks** tab.

This is standard GitHub Actions behavior, not a Hall architectural choice. The Hall's actual tracking mechanism is the **status card** — an HTML comment updated on each issue/PR at every dispatch stage. The check run provides bonus visibility: did the dispatch workflow itself succeed or fail, independently of what the agent did.

**Verdict: side effect, not harmful, arguably useful as a secondary signal.**

---

## Is the CI re-dispatch loop safe from self-triggering?

A valid concern: Hall's own `invoke.yml` runs produce check suites. Could `hall-ci-loop.yml` re-trigger on them, creating a loop?

No. `detect-ci-context.js` filters on `suite.head_branch`. When `invoke.yml` runs in response to a `pull_request_review`, the workflow executes on the **default branch** (`main`), not on a `hall/*` branch. The branch filter rejects it. The loop cannot feed back on itself.

---

## Why the current design holds

| Property | Value |
|----------|-------|
| Zero target-repo cooperation | Hall does not modify target repos to receive signals |
| Covers all CI without enumeration | Any failing check suite on a `hall/*` branch triggers re-dispatch |
| Native platform event | `check_suite.completed` is the idiomatic GitHub signal for "CI finished" |
| Self-loop safe | Branch filter blocks Hall's own workflow runs from triggering re-dispatch |

---

## The visual noise problem and the fix

Hall dispatch workflow runs (`[Hall] Invoke Agent`, `[Hall] CI Re-dispatch Loop`) appear in the PR Checks tab alongside target-repo CI (`tests`, `lint`, etc.). They are categorically different — Hall activity vs. CI validation — but GitHub renders them identically.

**Fix applied:** Hall's dispatch workflow names are prefixed with `[Hall]`. This is a cosmetic change with zero structural impact. Contributors can immediately distinguish Hall-activity checks from CI checks without inspecting the run.

No structural change to the `check_suite.completed` mechanism is warranted. Alternatives evaluated:

| Alternative | Trade-off |
|-------------|-----------|
| Explicit Check Runs API | More descriptive UI; more plumbing to maintain |
| `workflow_run` trigger | More targeted; requires naming conventions in every target repo — breaks zero-config |
| `repository_dispatch` for review path | Avoids dispatch check noise; significantly complicates trigger path; CI loop still needs `check_suite` |

None of these improve on the rename without adding complexity or breaking the zero-config model.
