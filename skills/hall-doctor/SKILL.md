---
name: hall-doctor
description: Run preflight diagnostics for the Hall of Automata plugin environment
argument-hint: [--fix]
allowed-tools: [Bash, Read]
---

# /hall:doctor

Run a full preflight diagnostic of the Hall of Automata environment. Use `--fix` to automatically repair issues that can be fixed (missing gitignore entry, stale cache).

## Checks to run

Run all checks and display results as a table. Mark each ✓ (pass), ✗ (fail — blocks session), or ⚠ (warn — session possible but degraded).

### 1. gh CLI authentication (✗ if fails)

```bash
gh auth status
```

Parse for "Logged in to github.com". Fail if not authenticated.

### 2. GITHUB_PERSONAL_ACCESS_TOKEN set (⚠ if missing)

```bash
echo "${GITHUB_PERSONAL_ACCESS_TOKEN:-NOT_SET}"
```

The GitHub MCP needs this. Warn if missing; the session works without it but the GitHub MCP won't connect.

### 3. Hall App installed on target repo's org (✗ if fails)

```bash
ORG=$(gh repo view --json nameWithOwner -q '.nameWithOwner | split("/")[0]')
gh api /orgs/${ORG}/installations \
  --jq '[.installations[].app_slug] | contains(["hall-of-automata"])' 2>&1
```

- `true` → PASS: Hall App is installed on this org
- `false` → FAIL: Hall App not installed; dispatch will not work
- HTTP error → ⚠ WARN: cannot verify (token lacks `admin:org` scope); assume installed and continue

### 4. Invoker / local mode status (ℹ informational)

```bash
python3 -c "
import json, sys
try:
    d = json.load(open('.hall-cache/invoker.json'))
    print(d.get('mode', '?'), '(verified', d.get('verified_at', '?') + ')')
except FileNotFoundError:
    print('NOT_VERIFIED')
"
```

- `invoker` → ✓ PASS: full dispatch mode active
- `local` → ✓ PASS: local mode active — Old Major implements inline; no Hall dispatch
- `NOT_VERIFIED` → ⚠ WARN: cache absent; run `/hall:open` to set mode

To reset mode: `hall-prune --invoker` clears the cache; next `/hall:open` re-verifies.

### 5. .hall-cache/ in .gitignore (⚠ if missing, fix with --fix)

```bash
grep -q "\.hall-cache" .gitignore 2>/dev/null && echo "present" || echo "missing"
```

If `--fix` passed, append `.hall-cache/` to `.gitignore`.

### 6. Persona cache freshness (⚠ if stale or missing)

```bash
cat .hall-cache/personas/.fetched_at 2>/dev/null || echo "not cached"
```

Warn if the timestamp is >24h ago or the file doesn't exist.

### 7. MCP connectivity (⚠ for each failed server)

Run `claude mcp list` and check for ✓ Connected status on `sequential-thinking`, `fetch`, `github`, and `google-drive`.

### 8. Hall quota (informational)

```bash
gh api /repos/$(gh repo view --json nameWithOwner -q .nameWithOwner)/issues \
  --jq '[.[] | select(.labels[].name | startswith("hall:")) | select(.state=="open")] | length'
```

Count open Hall issues on this repo (rough proxy for in-flight work). Display as info; not a pass/fail.

## Output format

Display as a two-column table: check name and result. End with a summary line:

```
✓ 6/8 checks passed  ⚠ 2 warnings  ✗ 0 blockers

Ready to /hall:open.
```

or

```
✓ 5/8 checks passed  ⚠ 1 warning  ✗ 2 blockers

Cannot start session: gh authentication required, Hall App not installed.
```
