# Hall of Automata — Claude Code Plugin

Local orchestrator for multi-task projects on a [Hall of Automata](https://github.com/MockaSort-Studio/hall-of-automata) instance. Plan decomposition, agent dispatch, and task coordination — all via a design conversation with Old Major.

## Prerequisites

- [Claude Code](https://claude.ai/code) CLI (`claude` / `cc`)
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated to the org that hosts your Hall instance
- An org installed [Hall of Automata](https://github.com/marketplace/hall-of-automata) 
- `GITHUB_PERSONAL_ACCESS_TOKEN` set in your environment (required for MCP connectivity)

## Installation

### Via MockaSort Marketplace (recommended)

Inside any Claude Code session:

```
/plugin marketplace add MockaSort-Studio/marketplace
/plugin install hall-of-automata-cli@mockasort
```

Works in the CLI, desktop app, and IDE extensions — no git or terminal required.

### Manual (CLI only)

```bash
git clone https://github.com/MockaSort-Studio/hall-of-automata-cli
claude --plugin-dir /path/to/hall-of-automata-cli
```

To load permanently without the flag, add to `~/.claude/settings.json` (Linux/macOS) or `%APPDATA%\Claude\settings.json` (Windows):

```json
{
  "plugins": [
    { "path": "/path/to/hall-of-automata-cli" }
  ]
}
```

## Quick Start

Open a Claude Code session inside your project repo, then:

```
/hall:doctor          — verify prerequisites and Hall connectivity
/hall:open            — start a session, load Old Major, pull advisory personas
/hall:plan            — design the project with Old Major (outputs plan.json)
/hall:dispatch        — create GitHub issues for ready tasks
/hall:status          — see task states (BACKLOG → IN_PROGRESS → DONE)
/hall:reconcile       — sync local plan.json with GitHub label changes
/hall:close           — wrap up, clean .hall-cache/
```

On first `/hall:open`, Old Major asks whether you are a Hall invoker (a member of `automata-invokers` in your org). Invokers get full dispatch mode; non-invokers get local mode, where Old Major implements tasks inline without filing GitHub Issues. The result is cached — subsequent opens skip the question. To re-verify: `/hall:open --verify` or `/hall:prune --invoker` then re-open.

## Commands

| Command | What it does |
|---|---|
| `/hall:doctor` | Checks gh auth, token, Hall App install, invoker/local mode status, MCP health |
| `/hall:open [--refresh\|--verify]` | Pulls personas + methodology, assembles session stack, runs invoker detection gate, starts watcher daemon |
| `/hall:plan` | Guided decomposition conversation with Old Major; writes `plan.json` |
| `/hall:dispatch` | Files issues for READY tasks (15 s apart to avoid invoker-pool races) |
| `/hall:status` | Renders task board from `plan.json` |
| `/hall:reconcile` | Pulls GitHub label changes → updates `plan.json` statuses |
| `/hall:consultations` | Routes a design question to the right specialist (Tier 1/2/3) |
| `/hall:reply` | Attaches a message to an in-flight task's GitHub issue |
| `/hall:prune [--invoker]` | Clears invoker cache (`--invoker`), removes old plans, or flushes persona cache |
| `/hall:close` | Saves session notes, kills watcher, removes `.hall-cache/` |

## Environment

The plugin writes all session state under `.hall-cache/` (gitignored). Nothing is committed to your project repo.

```
.hall-cache/
  personas/          # pulled from Hall roster at /hall:open
  methodology/       # pulled from Hall at /hall:open
  session/
    claude-agents/   # rendered subagent overlays (one per specialist)
  plan.json          # task graph, updated by reconcile
  CLAUDE-stack.md    # assembled session prompt stack
  watcher.pid        # background sync daemon
  watcher.log
```

## Security

The `guard-writes` hook enforces that subagents can only write inside `.hall-cache/` and `.gitignore`. Writes to your project source tree are blocked by default.
