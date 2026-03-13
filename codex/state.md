---
icon: material/map-clock
---

# State, Roadmap & Limitations

---

## Current State — Beta

The Hall is **functional but not packaged**. Everything works; nothing is one-click installable.

What exists today is a **template repository**: all workflows, composite actions, scripts, routing logic, and documentation are there and replicable by anyone willing to read through it. There is no published GitHub App in the Marketplace, no Helm chart, no installer. Deploying the Hall in a new org means:

1. Forking (or using the template) and customising the repo.
2. Registering a GitHub App manually and pointing its webhook at a self-hosted relay.
3. Onboarding at least one invoker before any dispatch can run.

This is intentional for now — the architecture is still settling, and locking it into a polished installation surface too early would create migration debt. The beta is the right vehicle for validating the design under real conditions.

**What is stable:**

- Invoker pool selection, weekly quota tracking, and nightly retry.
- Full dispatch lifecycle: label trigger → authorize → dispatch → status card → cleanup.
- Old Major onboarding and PR creation flow.
- CI loop (re-dispatch on failure up to `max_retries`).
- Cross-repo dispatch via App webhook + Fly.io relay.
- Composite action interface (`authorize`, `dispatch`, `memory`, `counter`, `status-card`, `cleanup`, `post-dispatch`).

**What is not stable:**

- Agent-to-agent coordination.
- The relay protocol (may change before v1).
- Audit artifact schema.

---

## Future Work — Federated Installation

The current model requires each org to self-host everything. The target model is a **federated app** where the infrastructure surface is minimal and shared, but the execution environment is fully isolated per org.

### What changes

| Layer | Today | Target |
|-------|-------|--------|
| GitHub App | Self-registered per org | Single published App; orgs install it |
| Relay | Self-hosted on Fly.io | Managed relay (shared infra) |
| Invoker pool | Configured manually per org | per-org, no shared state |
| Execution Environment | Repo file in the org's fork | Per-org, no shared state |
| Invoker secrets | `invoker/<handle>` envs in forked repo | `invoker/<handle>` envs in org's own Hall repo |

### What never changes

The principle of **zero shared state and zero shared secrets** is non-negotiable.

- No org's OAuth tokens, invoker counters, or task memories touch another org's environment.
- The shared surface is exclusively: the App identity, the relay routing logic, and the workflow templates.
- Secrets remain in GitHub Environments scoped to each org's own Hall repository.
- Anthropic API tokens never leave the runner that owns them.

This means the federated model is not a multi-tenant SaaS — it is a distributed system where the coordination layer is shared and the execution layer is always isolated. An org's Hall instance is architecturally equivalent to a self-hosted deployment; it just installs faster.

---

## Known Limitations

### Invoker pool race condition

Pool selection and counter increment are not atomic. The `detect` job reads all invoker usage counts, picks the least-used eligible invoker, and emits it as a job output. The `dispatch` job then increments the counter — but between detection and increment, a parallel dispatch can select the same invoker. Under concurrent load, an invoker can be dispatched past their weekly cap by the number of concurrent detections that happen before any increment lands.

**Mitigation in practice:** Concurrency groups (`hall-{agent}-{issue}`) serialize per agent+issue. The race only affects cross-issue parallelism, which is bounded by the org's dispatch rate. Acceptable for beta; needs a test-and-set at detection time for high-throughput orgs.

### Quota exhaustion retry has no jitter

Queued dispatches are retried by a nightly cron at 03:00 UTC. All queued issues fire simultaneously. If quota is still exhausted, all of them are re-queued for the following night. Under sustained quota shortage (API downtime, billing issues), this creates a thundering herd at the same wall-clock time every night. Fix: add per-issue jitter or stagger the retry window.

### GitHub API rate limit under large pools

The detect and select-invoker scripts paginate all `invoker/*` environments on every dispatch. With many invokers and a high dispatch rate, each round of dispatches makes several paginated API calls. The scripts have no backoff; under sustained load they would begin hitting the 5000 req/hr ceiling. Not a concern for small orgs; becomes critical past ~20 simultaneous invokers under continuous dispatch.

### Agent to Agent coordination

Routing a complex task to Old Major with the expectation that he will split it into subtasks and dispatch multiple agents in parallel is **not a supported workflow and not recommended**.

The problem is structural: agents run in isolation. There is no inter-agent messaging, no shared working memory, no dependency graph, and no coordinator that can block agent B until agent A's PR lands. If Old Major creates three sub-issues and labels each for a different specialist, those three specialists will:

- Each check out the target repo from `main` (or the same branch) independently.
- Race to open PRs with potentially conflicting changes.
- Have no visibility into what the others are doing or have done.

Managing the merge order, preventing conflicts, and synthesising the results falls entirely back on the human. In practice this is *more* work than doing the task linearly, not less.

**The correct pattern** for multi-component tasks is:

1. Open one issue describing the full task in Advise.
2. Ask explicitly to decompose tasks and create sub issues.
3. Old-Major analyses and decomposes.
4. Review and assign.

The above described behaviour happens automatically if Old-Major detects that the task is non-trivial and directly proposes decomposition.