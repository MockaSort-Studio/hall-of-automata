---
icon: material/robot
---

# Runner Model

## Execution layers

| Layer | Where it runs | What it does |
|-------|--------------|-------------|
| **Detect job** | GitHub-hosted runner | Thin event parsing: trigger type, invoker, agent (if labeled), issue/PR number |
| **Old Major triage job** | GitHub-hosted runner (pool-selected `invoker/<handle>` env) | Reads roster catalog, analyzes task, selects agent, synthesizes context. Only runs on the assignment path. |
| **Dispatch job** | GitHub-hosted runner (pool-selected `invoker/<handle>` env) | Persona injection, Claude Code Action, status card, counter update, audit log |
| **Claude inference** | Anthropic infrastructure | Language model processing; called by the Claude Code Action via OAuth token |

The GitHub runner checks out the target repository, assembles the CLAUDE.md context file from the base contract and agent persona, and runs `anthropics/claude-code-action@v1`. The action drives the agentic loop: calling Claude, executing bash/file tools, and committing results — all on the runner.

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

## GitHub Environments and secret isolation

Each agent's OAuth token lives in a GitHub Environment (`hall/{agent}`). The dispatch job declares `environment: hall/{agent}` (computed dynamically from the detected agent). This gives access to that environment's secrets and allows environment-level protection rules (e.g., required reviewers for certain agents).

---

## Persona injection

At dispatch time, the workflow assembles the agent's operating context:

1. Read `agents/automaton_base.md` from the Hall repo (checked out in the workflow)
2. Fetch the agent's persona character sheet from its Gist (ID read from the `hall/<agent>` deployment payload)
3. Concatenate base contract + persona → write to `CLAUDE.md` in the workspace root
4. If the target repo has its own `CLAUDE.md`: move it to `.hall-local.md` before writing the Hall's CLAUDE.md
5. Pass task context as the `prompt` input to the Claude Code Action, including an instruction to read `.hall-local.md` and extract hard constraints

`CLAUDE.md` and `.hall-local.md` are never committed. The runner is ephemeral — they exist only for the duration of the dispatch job. The base contract (`automaton_base.md`) explicitly prohibits the agent from committing either file.

---

## State persistence

The runner is ephemeral, but task state persists between runs via:

- **Actions Cache:** per-task working memory (`hall-task-{repo}-{pr}`). Keyed by PR so multiple concurrent tasks on different PRs never collide.
- **GitHub Deployments:** automaton lifecycle. `hall/<agent>` env holds a singleton deployment whose payload maps `persona_gist_id` and `dashboard_gist_id`. Updated (not recreated) on each invocation.
- **GitHub Gists:** persona and dashboard content. Dashboard gist is appended after each dispatch with an audit log entry and updated metrics.
- **Environment variables (`HALL_USAGE_COUNT`, `HALL_WEEKLY_CAP`):** keeper usage tracking. Written by the workflow via the GitHub API after each successful dispatch.
- **Actions Artifacts:** immutable invocation audit logs (`hall-log-{agent}-{issue}-{run_id}`)
- **GitHub issue/PR thread:** permanent human-readable task history; serves as fallback context if cache expires

See `architecture/` overall and the design document for the full state model.

---

## Tradeoffs

| Tradeoff | Consequence |
|----------|-------------|
| GitHub-hosted runners only | No persistent environment, no local tooling beyond what the runner image provides; target repo must be checked out |
| App private key in repo secrets | Visible to repo admins — see [`secrets-model.md`](secrets-model.md) |
| Cache as working memory | 7-day expiry; agent reconstructs from issue thread on miss |
| Dynamic `environment:` expression | GitHub evaluates this at job start; the environment must exist before the first dispatch |
