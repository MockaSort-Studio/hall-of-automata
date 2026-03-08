# Runner Model

## Execution layers

| Layer | Where it runs | What it does |
|-------|--------------|-------------|
| **Dispatch workflow** | GitHub-hosted runner (Hall repo) | Auth, cap check, routing, persona injection, status card, counter, audit log |
| **Agent (Claude Code Action)** | GitHub-hosted runner (target repo checkout) | Reads issue, writes code, opens PR, pushes commits |
| **Claude inference** | Anthropic infrastructure | Language model processing; called by the Claude Code Action via OAuth token |

The GitHub runner checks out the target repository, injects the agent persona, and runs `anthropics/claude-code-action@v1`. The action drives the agentic loop: calling Claude, executing bash/file tools, and committing results — all on the runner. The runner is not stateless for the duration of a dispatch; it holds the working tree.

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

## State persistence

The runner is ephemeral, but task state persists between runs via:

- **Actions Cache:** weekly invocation counters (`hall-counters-{YYYY}-W{WW}`) and per-task memory (`hall-task-{repo}-{pr}`)
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
