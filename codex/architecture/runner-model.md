---
icon: material/robot
---

# Runner Model

## Execution layers

| Layer | Where it runs | What it does |
|-------|--------------|-------------|
| **Detect job** | GitHub-hosted runner | Thin event parsing: trigger type, actor, agent (if labeled), issue/PR number; pool-selects invoker |
| **Dispatch job** | GitHub-hosted runner (`invoker/<handle>` env) | Persona injection, Claude Code Action, status card, counter update, audit log |
| **Claude inference** | Anthropic infrastructure | Language model processing; called by the Claude Code Action via OAuth token |

The GitHub runner checks out the Hall repo, assembles the CLAUDE.md context file from the base contract and agent persona, and runs `anthropics/claude-code-action@v1`. The action drives the agentic loop: calling Claude, executing bash/file tools, and committing results — all on the runner.

---

## GitHub-hosted runners

Runners are ephemeral VMs managed by GitHub. They spin up on workflow trigger, execute all steps, and are destroyed. No org member maintains infrastructure.

What runs on the runner:
- GitHub App token creation (`actions/create-github-app-token@v1`)
- Composite action steps: `authorize`, `counter`, `status-card`, `memory`, `dispatch`, `post-dispatch`, `cleanup`
- Shell scripts in `scripts/` (yq config reads, context injection, cache operations)
- The Claude Code Action agentic loop (bash, file r/w, git operations on the checked-out target repo)

---

## Composite action model

All orchestration logic lives in `actions/` as GitHub composite actions. The dispatch workflows (`invoke.yml`, `hall-ci-loop.yml`, `hall-cleanup.yml`) call these actions. This separation means:
- Orchestration logic is versioned and reusable
- Target repos require no local configuration — the Hall repo is the single source of logic
- Individual action steps can be tested or replaced independently

---

## Concurrency controls

Each dispatch job declares:

```yaml
concurrency:
  group: hall-{agent}-{issue-number}
  cancel-in-progress: false
```

This ensures at most one active dispatch per agent per issue at any time. Re-dispatches queue behind the running job rather than cancelling it.

---

## Invoker pool and environment selection

Each dispatch runs in the environment of the pool-selected invoker (`invoker/<handle>`). Pool selection happens in the `detect` job via `scripts/detect-invoke-context.js`, which:

1. Lists all `invoker/*` environments via the GitHub Environments API
2. Reads `HALL_USAGE_COUNT` and `HALL_WEEKLY_CAP` for each
3. Filters out members at or over cap
4. Sorts by `HALL_USAGE_COUNT` ascending
5. Outputs the least-used member as `invoker`

The dispatch job then declares `environment: invoker/<handle>` dynamically. This gives access to that environment's `CLAUDE_CODE_OAUTH_TOKEN` secret.

If the pool is exhausted (all members at cap), the `invoker` output is empty, the `notify-queued` job fires, and the dispatch job is skipped.

---

## Persona injection

At dispatch time, the workflow assembles the agent's operating context:

1. Read `agents/automaton_base.md` from the Hall repo (checked out in the workflow)
2. Read `roster/{agent}.md` from the Hall repo — the agent's character sheet
3. Concatenate base contract + persona → write to `CLAUDE.md` in the workspace root
4. Pass task context as the `prompt` input to the Claude Code Action

`CLAUDE.md` is never committed. The runner is ephemeral — it exists only for the duration of the dispatch job. The base contract (`automaton_base.md`) explicitly prohibits the agent from committing the file.

---

## State persistence

The runner is ephemeral, but task state persists between runs via:

- **Actions Cache:** per-task working memory (`hall-task-{repo}-{pr}`). Keyed by PR so multiple concurrent tasks on different PRs never collide. 7-day TTL; deleted on PR close by `hall-cleanup.yml`.
- **Environment variables (`HALL_USAGE_COUNT`, `HALL_WEEKLY_CAP`):** invoker usage tracking. Written by the workflow via the GitHub API after each successful dispatch.
- **Actions Artifacts:** immutable invocation audit logs (`hall-log-{agent}-{issue}-{run_id}`)
- **GitHub issue/PR thread:** permanent human-readable task history; serves as fallback context if cache expires
- **`agents.yml` and `roster/*.md`:** live catalog and persona state, version-controlled in the Hall repo

---

## Tradeoffs

| Tradeoff | Consequence |
|----------|-------------|
| GitHub-hosted runners only | No persistent environment; target repo must be checked out |
| App private key in repo secrets | Visible to repo admins — see [`secrets-model.md`](secrets-model.md) |
| Cache as working memory | 7-day expiry; agent reconstructs from issue thread on miss |
| Dynamic `environment:` expression | GitHub evaluates this at job start; the invoker environment must exist before the first dispatch |
| Pool-based token model | No dedicated per-agent token; any invoker's token can run any agent |
