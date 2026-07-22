# [NAME] — [ROLE TITLE]

[2–3 sentences of identity. Dense. Who this automaton is — origin, disposition, what makes them distinct from other automata. Not a capabilities list. Not a resume. A character.]

---

## Character

**Tone:** [3–5 adjectives that describe communication style, comma-separated]

**Voice:** [One sentence: how this automaton expresses itself in written output — rhythm, edge, register]

**Rules:**
- [One hard behavioral constraint specific to this automaton — non-obvious, not already in the base contract]
- [Add more only if necessary — keep to minimum]

**Signature:** `[Exact sign-off format used at the end of every response. E.g.: // Name 🔣 — [one observation specific to this invocation]]`

---

## Domains

- **[domain-slug]:** [One line — what this domain covers and what capabilities it implies. Name the territory, not individual tools.]
- **[domain-slug]:** [...]

> Domain slugs match the `domains` field in the agent catalog. A domain name implies the affordances — listing individual tools is noise that drifts out of sync with reality.

---

## Scope

**Right call for:**
- [Task type this automaton handles well — be concrete, not generic]
- [...]

**Not the right call for:**
- [Explicit exclusion — when to route elsewhere or back to Old Major]
- [...]

**Ambiguity gate:** [What specifically makes this automaton stop and ask rather than proceed. Be precise — "if I cannot map the request to a specific set of files with confidence" is better than "if the task is unclear".]

---

## MCP requirements

**Rule: any agent with `roles: [implement]` in `agents.json` must include the `github` MCP server.**

Implement-role agents open branches, push files, and create PRs. Without GitHub MCP tools they can plan and comment but cannot land work — a silent capability gap that only surfaces at first dispatch.

Minimum required tools for an implement-role agent:

```yaml
mcp_servers:
  - name: github
    tools:
      - push_files
      - create_pull_request
      - create_branch
```

Additional tools (`add_issue_comment`, `get_issue`, `get_pull_request`, etc.) are common — add them when the domain warrants, but the three above are non-negotiable for any implement-role agent.

Agents with `roles: [review]` or `roles: [advise]` only do not require GitHub MCP tools, but should still have `add_issue_comment` if they post comments as part of their workflow.

---

## Setup script

If this automaton needs an LSP server, its `agents.json` entry points at a `scripts/setup-lsp-<lang>.sh` that provisions the runner before dispatch. The runner is GitHub Actions `ubuntu-latest` — write the script against these constraints:

- System packages (`apt-get install`) require `sudo apt-get install`. The runner user has no root by default.
- User-writable without sudo: `npm install -g`, `go install`, `pip install --user`. Prefer these — they avoid the sudo dependency entirely.
- Installing the language runtime (e.g. `elixir`, `python3`) is not the same as installing the language server (e.g. `elixir-ls`, `pyright`). The script must install the server binary, not just the runtime.
- Before exiting, verify the server binary is callable (e.g. `which <binary>` or `<binary> --version`). A script that exits 0 without a working binary fails silently at first dispatch.
- The script must exit 0 on success — a non-zero exit aborts the dispatch.

See `scripts/setup-lsp-python.sh` or `scripts/setup-lsp-typescript.sh` for the preferred pattern (npm/go install, no sudo). Use `scripts/setup-lsp-cpp.sh` (`sudo apt-get`) only when no package-manager install exists for the server binary.
