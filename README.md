# Hall of Automata

> *A place on another plane...*

Hall of Automata is a GitHub-native AI agent orchestration system. It runs entirely on GitHub Actions — no server, no billing account, no external runtime. Labels are the message bus. Actions are the execution layer. Environments hold your secrets.

Specialists are dispatched by label, work inside a GitHub Actions runner, and close their own issues by opening reviewed PRs. You never leave GitHub.

---

## How it works

1. **Label an issue** with a specialist label (e.g., `hall:snowball`, `hall:pyrate`).
2. `invoke.yml` fires on `issues.labeled`, reads the label, and selects a live invoker token from the pool.
3. The specialist runs as Claude Code inside a GitHub Actions runner — bare (standard runner) or containerized (your dev environment via `.hall-contract.yaml`).
4. The specialist opens a PR. If a reviewer requests changes, `REQUEST_CHANGES` re-invokes the same specialist on the PR.
5. CI failure re-triggers the specialist automatically via `hall-ci-loop.yml` until the build is green or the loop cap is hit.

### Invoker pool

A pool of personal Claude OAuth tokens lives in GitHub Environment secrets (`hall-invoker-1`, `hall-invoker-2`, …). On each dispatch, a least-used invoker is selected and its weekly cap is tracked. Tokens are rotated by you — Hall tracks usage, not credentials.

---

## Main features

| Feature | Description |
|---|---|
| Specialist roster | 10 domain specialists + Old Major session orchestrator |
| Review loop | `REQUEST_CHANGES` on a specialist's PR re-invokes and addresses feedback |
| CI re-dispatch | `hall-ci-loop.yml` re-triggers the specialist on CI failure until green |
| Containerized dispatch | `.hall-contract.yaml` opts a repo into running specialists inside its own dev container — enables TDD |
| Sync | `hall-sync.yml` propagates Hall updates from MockaSort-Studio to all installed org repos |
| Cross-repo dispatch | Issues in any repo in your org can invoke Hall specialists |

---

## Containerized dispatch and TDD

By default, specialists run in a standard GitHub Actions runner. If your repo ships a `Dockerfile` that extends the Hall base image, you can opt into containerized dispatch:

```yaml
# .hall-contract.yaml  (place in repo root)
image: ghcr.io/your-org/your-repo-dev:latest
```

When `invoke.yml` finds `.hall-contract.yaml` with an `image:` field, it switches to `dispatch-containerized`. The specialist runs inside your dev container — with your toolchain, test runner, and local build cache available. This enables true TDD: write a failing test in the issue, the specialist runs it inside your environment, and doesn't open a PR until the test passes.

The Hall base image (`ghcr.io/mockasort-studio/hall-dispatch-base-image:latest`) ships Node.js 20, `gh`, `git`, `jq`, and `yq`. Extend it in your own `Dockerfile` to add your language runtime and tools.

---

## Agents

| Agent | Emoji | Domains | Roles |
|---|---|---|---|
| **Old Major** | | Session orchestrator — plans, dispatches, reconciles. Use [hall-of-automata-cli](https://github.com/MockaSort-Studio/hall-of-automata-cli) to work with Old Major interactively. | plan, dispatch, reconcile |
| **Snowball** | 🐷 | Hall infrastructure, persona engineering | implement, review |
| **Hamlet** | 🐗 | C++17, build systems, debugging | implement, debug, triage |
| **Captain Pyrate** | 🦜 | Python | implement, debug |
| **mergio** | 🤘 | CI/CD, GitOps, build systems, infrastructure, deployment | implement, debug, triage |
| **Frontenzo** | 🎨 | Frontend architecture, UX/UI, web performance, accessibility | advise, review, research |
| **AEEEEEIII** | 🐑 | AI perception, environment modeling, computer vision, autonomous systems | research, advise, synthesize |
| **Tomashco** | 🛹 | API design, event-driven architecture, data security, backend triage | advise, research, triage |
| **Indiana Docs** | 🤠 | Documentation | write, review, research |
| **Frontenzio** | 🛠️ | React, TypeScript, Vite, Astro, CSS, frontend debugging | implement, debug |
| **Panoramix** | 🧪 | Elixir, Phoenix, Ecto, BEAM, testing | implement, debug, test |

---

## Invoking

**Dispatch a specialist:**
Label any issue in your org with `hall:<slug>` (e.g., `hall:pyrate`, `hall:snowball`).

**Request changes:**
On a specialist's open PR, submit a review with `REQUEST_CHANGES`. The same specialist is re-invoked and addresses the feedback.

**Cross-repo dispatch:**
Issues in any repo in your org can use Hall labels — dispatch is not limited to the `hall-of-automata` repo itself.

**Planning with Old Major:**
Use [hall-of-automata-cli](https://github.com/MockaSort-Studio/hall-of-automata-cli) to open an interactive Old Major session in your terminal. Old Major reads your project board, drafts plans, writes OKRs, and dispatches work from a structured session — no manual labeling required.

---

## Repository layout

| Path | Purpose |
|---|---|
| `.github/workflows/invoke.yml` | Entry point — fires on `issues.labeled`; selects invoker; routes to bare or containerized dispatch |
| `.github/workflows/dispatch-bare.yml` | Runs specialist in standard GHA runner |
| `.github/workflows/dispatch-containerized.yml` | Runs specialist inside repo-supplied dev container |
| `.github/workflows/hall-ci-loop.yml` | Re-triggers specialist on CI failure |
| `.github/workflows/hall-sync.yml` | Syncs Hall updates from MockaSort-Studio to installed org repos |
| `.github/workflows/base-image.yml` | Builds the Hall dispatch base Docker image (MockaSort-Studio only) |
| `agents/agents.yml` | Full agent catalog with personas, models, labels, and routing |
| `agents/automaton_base.md` | Mandatory base contract every specialist must follow |
| `agents/old-major.md` | Old Major persona and dispatch methodology |
| `docker/` | Dockerfile for the Hall dispatch base image |
| `scripts/` | Runtime scripts used by dispatch workflows |
| `actions/` | Composite actions (invoker selection, token rotation, etc.) |

---

## Codex

Full reference documentation lives in the [Hall Codex](https://github.com/MockaSort-Studio/hall-codex).
