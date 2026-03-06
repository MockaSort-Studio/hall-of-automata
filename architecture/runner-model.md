# Runner Model

## Responsibilities

The system has two distinct execution environments:

| Layer | Where it runs | What it does |
|-------|--------------|-------------|
| **Workflow** | GitHub-hosted runner | Team check, label management, API call, result posting |
| **Automaton** | Anthropic infrastructure | Receives issue context, generates response |

The GitHub runner does not run the automaton. It calls the Anthropic API with the issue context and waits for the response. Claude runs on Anthropic's servers.

---

## GitHub-hosted runners

Runners are ephemeral VMs managed by GitHub. They spin up on workflow trigger, execute the workflow steps, and are destroyed. No member of the org maintains infrastructure. No machine needs to be online.

What runs on the runner:
- Team membership check via GitHub API
- Label removal if unauthorized
- Construction of the prompt from issue context
- HTTP call to Anthropic API (`ANTHROPIC_KEY_[AGENT]` from org secrets)
- Posting the response back as an issue comment

---

## What this means in practice

**Available 24/7.** Not tied to any member's uptime. A label applied at any time dispatches immediately.

**Stateless.** Each invocation is a fresh runner. No state carries between runs. Context must be in the issue — title, body, comments. The workflow can optionally check out the repository to include file content in the prompt.

**Isolated.** Concurrent invocations run in separate environments. Concurrency controls at the workflow level prevent racing on the same issue.

---

## Tradeoffs

| Tradeoff | Consequence |
|----------|-------------|
| API keys in org secrets | Keys are managed by GitHub, visible to org admins — see [`secrets-model.md`](secrets-model.md) |
| No persistent runner environment | No caching, no local state — anything the automaton needs must be fetched per run |
| Context window bounded by issue content | The automaton sees what is in the issue; repo access requires explicit checkout in the workflow |

The self-hosted runner alternative was evaluated and rejected. The full reasoning is in [`codex/design-options.md`](../codex/design-options.md).
