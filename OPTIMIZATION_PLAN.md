# Hall Automata Optimization Plan

> **Status:** Design complete — ready for implementation.
> Last updated: 2026-03-24
> Informed by: Borys Cherny's Claude Code philosophy, MCP ecosystem research, claude-code-action documentation.

---

## Guiding Principles

1. **Instrument before cutting.** The audit log already records `turns_used` per dispatch. Establish a real baseline before reducing `max_turns`. Blind cuts cause mid-task failures.
2. **Better tools → fewer turns naturally.** LSP queries replace exploratory file reads. Sequential thinking replaces correction loops. The goal is effective turns, not fewer turns.
3. **Verify before committing.** Cherny's clearest finding: giving an agent a way to check its own work yields 2–3× quality improvement. Every code agent should have a verification step.
4. **Personas are living documents.** Old Major owns the roster. Failed dispatches trigger post-mortem proposals. Persona files accumulate knowledge over time.
5. **`agents.yml` is the single source of truth.** Model, turns, MCP servers, tools — all declared there. No agent-specific branching in `invoke.yml`.

---

## What Changes and Where

```
hall-of-automata/
├── agents.yml                    ← add model, mcp, setup fields per agent
├── agents/
│   └── automaton_base.md         ← @import pattern, universal planning discipline
├── roster/
│   ├── old-major.md              ← add post-mortem + tool recommendation responsibilities
│   ├── mergio.md                 ← add CI self-check, planning discipline
│   ├── hamlet.md                 ← add LSP usage guidance, compile verification
│   └── pyrate.md                 ← add LSP usage guidance, test/lint verification
├── scripts/
│   └── build-mcp-config.js       ← NEW: reads agents.yml, emits /tmp/mcp.json
└── .github/workflows/
    └── invoke.yml                ← single generic MCP step (no per-agent branching)
```

---

## Phase 1 — Persona Architecture

*No MCP, no infra. Pure prompt engineering. Highest leverage, lowest risk.*

### 1.1 Switch CLAUDE.md injection to @import

**Current** (`actions/dispatch/action.yml`):
```bash
cat agents/automaton_base.md roster/${slug}.md > CLAUDE.md
```

**New:**
```bash
printf '@agents/automaton_base.md\n@roster/%s.md\n' "${slug}" > CLAUDE.md
```

Claude Code resolves `@`-imports at runtime from the checked-out repo. Dispatch writes a two-line file; persona updates take effect on next dispatch without touching dispatch logic.

### 1.2 Add universal planning discipline to `automaton_base.md`

```
## Planning discipline
Before writing any code, creating any file, or opening any PR:
1. State your understanding of the task in 2–3 sentences.
2. List the files you will touch and why.
3. Identify one thing that could go wrong and how you will check for it.
Only then proceed. If the task changes mid-execution, re-plan before continuing.
```

### 1.3 Add verification loops to each persona (`roster/<slug>.md`)

| Agent | Verification instruction |
|---|---|
| **old-major** | After writing to `agents.yml`, re-read it and confirm schema validity before closing the issue. |
| **mergio** | After modifying any workflow file, run `gh run list --limit 3` to confirm no existing runs are broken. Check CI status before opening a PR. |
| **hamlet** | After editing any `.cpp` or `.h` file, query LSP `diagnostics` on the changed file. Fix all errors before committing. |
| **pyrate** | After editing any `.py` file, run `python -m pytest --tb=short -q` on the affected module. Fix failures before committing. |
| **aeeeiii** | After producing a synthesis, re-read source material and confirm no unsupported claims. List sources inline. |

---

## Phase 2 — Model Selection per Agent

*Single field addition to `agents.yml`. Low implementation cost.*

### 2.1 `agents.yml` schema addition

```yaml
agents:
  old-major:
    model: claude-haiku-4-5        # triage/routing — fast, cheap
    max_turns: 20

  mergio:
    model: claude-sonnet-4-6
    max_turns: 25

  hamlet:
    model: claude-sonnet-4-6
    max_turns: 30

  pyrate:
    model: claude-sonnet-4-6
    max_turns: 25

  aeeeiii:
    model: claude-opus-4-6         # research synthesis — quality over cost
    max_turns: 20
```

**Note on max_turns:** Old-major drops from 100 (routing genuinely doesn't need it). Implementation agents are not reduced — wait for audit log data. Tuning rule: set `max_turns` to `observed_median + 5`. Never below that.

### 2.2 Wire `model` in dispatch

`detect-invoke-context.js` reads `agents.yml` and outputs `model`. `invoke.yml` passes `--model ${model}` in `claude_args`.

---

## Phase 3 — MCP Config Driven by `agents.yml`

*No per-agent branching in `invoke.yml`. One generic step reads the agent spec.*

### 3.1 `agents.yml` MCP schema

Each agent declares its MCP servers and allowed tools. The dispatch infrastructure reads this and builds the config automatically.

```yaml
agents:
  hamlet:
    model: claude-sonnet-4-6
    max_turns: 30
    mcp:
      servers:
        sequential-thinking:
          runtime: npx
          package: "@modelcontextprotocol/server-sequential-thinking"
        fetch:
          runtime: npx
          package: "@modelcontextprotocol/server-fetch"
        lsp:
          runtime: go-install
          package: github.com/isaacphi/mcp-language-server
          lsp_server: clangd
          lsp_args: ["--compile-commands-dir={{workspace}}"]
          setup: scripts/setup-lsp-cpp.sh
      allowed_tools:
        - mcp__sequential-thinking__sequentialthinking
        - mcp__fetch__fetch
        - mcp__lsp__definition
        - mcp__lsp__references
        - mcp__lsp__diagnostics
        - mcp__lsp__hover

  pyrate:
    model: claude-sonnet-4-6
    max_turns: 25
    mcp:
      servers:
        sequential-thinking:
          runtime: npx
          package: "@modelcontextprotocol/server-sequential-thinking"
        fetch:
          runtime: npx
          package: "@modelcontextprotocol/server-fetch"
        lsp:
          runtime: go-install
          package: github.com/isaacphi/mcp-language-server
          lsp_server: pyright-langserver
          lsp_args: ["--stdio"]
          setup: scripts/setup-lsp-python.sh
      allowed_tools:
        - mcp__sequential-thinking__sequentialthinking
        - mcp__fetch__fetch
        - mcp__lsp__definition
        - mcp__lsp__references
        - mcp__lsp__diagnostics
        - mcp__lsp__hover

  old-major:
    model: claude-haiku-4-5
    max_turns: 20
    mcp:
      servers:
        sequential-thinking:
          runtime: npx
          package: "@modelcontextprotocol/server-sequential-thinking"
        fetch:
          runtime: npx
          package: "@modelcontextprotocol/server-fetch"
        github-extended:
          runtime: npx
          package: "@github/github-mcp-server"
          env:
            GITHUB_PERSONAL_ACCESS_TOKEN: "{{secrets.GITHUB_TOKEN}}"
            GITHUB_TOOLSETS: "issues,labels,pull_requests"
      allowed_tools:
        - mcp__sequential-thinking__sequentialthinking
        - mcp__fetch__fetch
        - mcp__github-extended__search_issues
        - mcp__github-extended__create_label
        - mcp__github-extended__update_label

  mergio:
    model: claude-sonnet-4-6
    max_turns: 25
    mcp:
      servers:
        sequential-thinking:
          runtime: npx
          package: "@modelcontextprotocol/server-sequential-thinking"
      allowed_tools:
        - mcp__sequential-thinking__sequentialthinking
    # mergio already has mcp__github_ci__* via built-in CI tools

  aeeeiii:
    model: claude-opus-4-6
    max_turns: 20
    mcp:
      servers:
        sequential-thinking:
          runtime: npx
          package: "@modelcontextprotocol/server-sequential-thinking"
        fetch:
          runtime: npx
          package: "@modelcontextprotocol/server-fetch"
        # Search enhancement — choose one tier:
        #
        # Tier 0 (zero cost, no API key):
        # search:
        #   runtime: npx
        #   package: duckduckgo-mcp-server
        #
        # Tier 1 (free, 2000 req/month — recommended):
        # search:
        #   runtime: npx
        #   package: "@modelcontextprotocol/server-brave-search"
        #   env:
        #     BRAVE_API_KEY: "{{secrets.BRAVE_API_KEY}}"
        #
        # Tier 2 (self-hosted, unlimited):
        # search:
        #   runtime: npx
        #   package: mcp-searxng
        #   env:
        #     SEARXNG_URL: "{{secrets.SEARXNG_URL}}"
        #
        # Tier 3 (paid, best semantic quality):
        # search:
        #   runtime: npx
        #   package: exa-mcp-server
        #   env:
        #     EXA_API_KEY: "{{secrets.EXA_API_KEY}}"
      allowed_tools:
        - mcp__sequential-thinking__sequentialthinking
        - mcp__fetch__fetch
        # - mcp__search__search   ← uncomment when a search tier is chosen
```

### 3.2 New script: `scripts/build-mcp-config.js`

Reads `agents.yml` for the given agent slug and:

1. Generates `/tmp/mcp.json` with the `mcpServers` block
2. Resolves `{{workspace}}` and `{{secrets.X}}` placeholders from environment
3. Outputs `setup_script` (path to a setup shell script if any server needs it)
4. Outputs `allowed_tools` as a comma-separated string

### 3.3 `invoke.yml` — single generic MCP step

```yaml
- name: Build MCP config
  id: mcp
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    EXA_API_KEY: ${{ secrets.EXA_API_KEY }}
  run: node scripts/build-mcp-config.js ${{ needs.detect.outputs.agent }}

- name: Run LSP setup if needed
  run: |
    SETUP="${{ steps.mcp.outputs.setup_script }}"
    if [ -n "$SETUP" ]; then bash "$SETUP"; fi

- uses: anthropics/claude-code-action@v1
  with:
    claude_args: |
      --model ${{ needs.detect.outputs.model }}
      --mcp-config /tmp/mcp.json
      --allowedTools ${{ steps.mcp.outputs.allowed_tools }}
```

No `if: agent == 'X'` anywhere. Adding a new agent with new MCP requirements is a change to `agents.yml` only.

### 3.4 LSP setup scripts (called only when agent spec declares them)

**`scripts/setup-lsp-cpp.sh`:**
```bash
sudo apt-get install -y clangd
go install github.com/isaacphi/mcp-language-server@latest
if [ -f CMakeLists.txt ]; then
  cmake -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
  cp build/compile_commands.json .
fi
```

**`scripts/setup-lsp-python.sh`:**
```bash
npm install -g pyright
go install github.com/isaacphi/mcp-language-server@latest
```

---

## Phase 4 — Old Major as Roster Steward

*Old Major gains two new responsibilities: dynamic tool research during onboarding, and post-mortem analysis.*

### 4.1 Tool discovery during automaton onboarding

No static catalog. A maintained file falls behind the MCP ecosystem immediately and becomes a human maintenance burden. Old-major already has `fetch` and `exa` — it researches tools live from the character sheet, using the same sources a human expert would consult.

**Where old-major searches:**

| Source | URL | What it finds |
|---|---|---|
| MCP Registry API | `https://registry.modelcontextprotocol.io` | Official index, searchable by keyword |
| PulseMCP | `https://pulsemcp.com/servers` | Community adoption signals, quality indicators |
| Reference servers | `https://modelcontextprotocol.io/examples` | Canonical well-maintained servers |
| Awesome list | `https://github.com/punkpeye/awesome-mcp-servers` | Curated community picks |

**Old-major's research procedure** (add to `roster/old-major.md`):

```
## Tool provisioning
When onboarding a new automaton, after evaluating the character sheet:

1. Extract from the submission: programming languages, domains, roles, external
   services or APIs the agent will interact with.

2. For each language declared: search the MCP registry for language server
   support (LSP). Check if a well-maintained server exists for that language.

3. For each domain/role: fetch https://registry.modelcontextprotocol.io and
   search for relevant servers. Cross-reference with pulsemcp.com for adoption
   and maintenance signals. Prefer servers that are actively maintained and
   have clear documentation.

4. Always include:
   - sequential-thinking (universal — reduces correction loops for all agents)
   - fetch (for any agent that reads docs, specs, or URLs from issue bodies)

5. Include only tools the agent will genuinely use. Do not add tools speculatively.
   A tool that adds token overhead without being used is a cost, not a benefit.

6. Write the mcp: block in agents.yml as part of the provisioning PR.
   For each server chosen, write one sentence in the PR description explaining
   why it fits this agent's specific domains and roles.

7. If no suitable MCP server exists for a capability the agent needs, note it
   as a gap in the PR description. Do not invent a package name.
```

This means the character sheet template (`new-automaton.yml`) should have an explicit field for **programming languages and external services** — that's the primary input for tool research. Old-major uses `fetch` to query the MCP registry REST API (`https://registry.modelcontextprotocol.io/api/v0/servers?search={keyword}`) and read READMEs directly — the registry returns structured JSON, so semantic search is not needed for this task.

### 4.3 Post-mortem analysis and roster amendment proposals

Old-major gains a new trigger: `hall:post-mortem` label on any issue.

**Automatic trigger:** When `post-dispatch` records `outcome: failed` or `outcome: max_turns_exceeded` in the audit artifact, `invoke.yml` applies `hall:post-mortem` to the originating issue and triggers old-major.

**Old-major's post-mortem procedure** (add to `roster/old-major.md`):

```
## Post-mortem procedure
When dispatched with hall:post-mortem context:
1. Read the audit artifact: hall-log-{agent}-{issue}-{run_id}.json
2. Read the dispatch result: .hall/dispatch-result.json from the failed run
3. Identify the failure mode:
   - max_turns_exceeded → agent ran out of turns; propose reducing task scope in persona or
     adding a tool that would have shortened exploration
   - failed (token) → invoker token issue; not a persona problem
   - failed (other) → read the last turns for what went wrong
4. If the failure is addressable by a persona change:
   - Open a PR amending roster/{slug}.md with a ## Known failure modes entry
   - Propose the specific instruction that would have prevented this failure
   - Title the PR: "fix(roster): {slug} — {failure mode summary}"
5. If the failure is addressable by a tool addition:
   - Consult agents/mcp-catalog.md
   - Open a PR amending agents.yml with the appropriate mcp: addition
6. If the failure is not addressable (environment issue, external API, etc.):
   - Comment on the issue with the diagnosis and close it
```

**New label:** `hall:post-mortem` — add to the labels seeded during `onboard.js`.

---

## Per-Agent Summary

| Agent | Model | Max turns | MCP servers | LSP |
|---|---|---|---|---|
| **old-major** | Haiku | 20 | sequential-thinking, fetch, github-extended | — |
| **mergio** | Sonnet | 25 | sequential-thinking | — |
| **hamlet** | Sonnet | 30 | sequential-thinking, fetch, lsp | clangd |
| **pyrate** | Sonnet | 25 | sequential-thinking, fetch, lsp | pyright |
| **aeeeiii** | Opus | 20 | sequential-thinking, fetch, search (optional) | — |

All MCP config declared in `agents.yml`. New agents get their MCP spec written by old-major at onboarding time — old-major researches the live MCP ecosystem based on the agent's declared languages, domains, and roles.

---

## Implementation Sequence

```
Phase 1   Persona architecture       @import + verification loops + planning discipline
Phase 2   Model selection            agents.yml model field + detect-invoke-context.js output
Phase 3   MCP infrastructure         build-mcp-config.js + agents.yml mcp schema + invoke.yml generic step
Phase 3a  Universal MCP              sequential-thinking + fetch entries in agents.yml
Phase 3b  LSP integration            clangd (hamlet) + pyright (pyrate) + setup scripts
Phase 3c  Specialist MCP             exa (aeeeiii) + github-extended (old-major)
Phase 4   Old Major roster steward   mcp-catalog.md + post-mortem procedure + tool recommendation
```

Phases 1 and 2 are independent. Phase 3 is a single infrastructure investment (build-mcp-config.js) followed by incremental additions to `agents.yml` — 3a, 3b, 3c can ship separately. Phase 4 builds on Phase 3 (old-major needs the catalog to exist before it can recommend tools).

**Turns tuning:** After Phase 3a is live for 2+ weeks, read `turns_used` from audit artifacts per agent. Set `max_turns` to `observed_median + 5`. Never below that.
