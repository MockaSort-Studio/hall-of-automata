---
icon: material/lock
---

# Secrets Model

## What lives where

| Asset | Location | Type | Purpose |
|-------|----------|------|---------|
| `APP_ID` | Hall repo secret | Public identifier | GitHub App identity; used to mint installation tokens |
| `APP_PRIVATE_KEY` | Hall repo secret | Signs JWT requests | Generates GitHub App installation tokens |
| `CLAUDE_CODE_OAUTH_TOKEN` | `hall/<agent>` Environment secret | Claude Pro/Max subscription | Agent OAuth credential billed to keeper's subscription |
| `HALL_USAGE_COUNT` | `hall/<agent>` Environment variable | Integer | Weekly invocation count for this keeper's token |
| `HALL_WEEKLY_CAP` | `hall/<agent>` Environment variable | Integer | Configured weekly cap for this keeper |
| Persona gist ID | `hall/<agent>` Deployment payload | String | Reference to the agent's character sheet gist |
| Dashboard gist ID | `hall/<agent>` Deployment payload | String | Reference to the agent's metrics/audit/history gist |
| Catalog JSON | `hall/roster` Deployment payload | JSON | Full agent catalog read by Old Major at triage time |

---

## GitHub App secrets (`APP_ID`, `APP_PRIVATE_KEY`)

Stored as repository secrets on the Hall repo. Used by `actions/create-github-app-token@v1` at the start of each dispatch job to mint a short-lived installation token scoped to the target repo owner.

**What the installation token can do:** whatever permissions the App was granted at install time (Contents, Issues, Pull Requests R/W; Members R; Deployments R/W for lifecycle updates).
**Lifetime:** 1 hour. Never stored; minted fresh per job.

If `APP_PRIVATE_KEY` leaked, an attacker could mint installation tokens. Mitigation: immediate key rotation in the App settings (Settings → Private keys → Revoke).

---

## Per-agent OAuth tokens (`CLAUDE_CODE_OAUTH_TOKEN`)

Each agent's keeper runs `claude setup-token` on their machine, authenticates via their Claude Pro/Max subscription, and obtains an OAuth token. The token is stored as a secret in the agent's GitHub Environment (`hall/<agent>`).

**Isolation:** GitHub Environments allow environment-level secrets accessible only when the job explicitly declares `environment: hall/<agent>`. No job can access another agent's token unless it targets that environment.

**Billing:** Consumption is billed against the keeper's Claude subscription, not a shared API key. There is no Anthropic API key.

**Rotation:** If a token is compromised, the keeper runs `claude setup-token` again and updates the Environment secret. The old token is revoked automatically when the new one is issued.

---

## Keeper usage variables (`HALL_USAGE_COUNT`, `HALL_WEEKLY_CAP`)

Stored as **environment variables** (not secrets) on the `hall/<agent>` Environment. Variables are readable and writable via the GitHub Environments API.

`HALL_USAGE_COUNT` is incremented by the workflow after each successful dispatch using the Environments API (with the App's installation token, which has Deployments write permission). `HALL_WEEKLY_CAP` is set once by the keeper admin and updated manually when the cap needs adjustment.

**Cap scope:** per keeper environment (per-agent, in the current 1:1 keeper-to-agent model). If a keeper manages multiple agents, each agent env tracks usage independently. The keeper's total consumption across all their agents is the sum. Future: if a keeper has multiple agents, a shared `hall/<keeper>` env would hold the OAuth token and usage count, with each agent env holding only deployment metadata.

**No weekly reset job needed:** `HALL_USAGE_COUNT` is reset to 0 by the workflow on the configured reset day (from `routing.yml`) using the same API write. The counter in `routing.yml` carries the reset schedule; the variable carries the live count.

---

## Deployment payloads

Each `hall/<agent>` environment has one singleton GitHub Deployment. It is created during onboarding and updated (never recreated) at each invocation. The deployment payload is a JSON object:

```json
{
  "persona_gist_id": "<gist-id>",
  "dashboard_gist_id": "<gist-id>"
}
```

The `hall/roster` environment has one singleton deployment. The payload is the full agent catalog:

```json
{
  "updated_at": "2026-03-09T00:00:00Z",
  "agents": {
    "hamlet": {
      "display_name": "Hamlet 🐗",
      "keeper": "mksetaro",
      "keeper_env": "hall/hamlet",
      "roles": ["implement", "fix", "refactor"],
      "domains": ["cpp", "build-systems", "devops"],
      "scope_summary": "...",
      "persona_gist_id": "<gist-id>",
      "dashboard_gist_id": "<gist-id>"
    }
  }
}
```

Old Major reads this payload in one API call to get the full routing context. No per-agent API calls needed during triage.

---

## Token masking

The dispatch action masks the OAuth token immediately upon access:

```yaml
- name: Mask OAuth token
  run: echo "::add-mask::${{ inputs.oauth-token }}"
```

This prevents the token value from appearing in any subsequent log output, including debug mode.

---

## What GitHub does not hold

- No Anthropic API keys
- No billing credentials
- No keeper personal passwords or SSH keys

---

## Token management procedures

Rotation and emergency procedures are in [`../key-management.md`](../key-management.md).

---

## GitHub App secrets (`APP_ID`, `APP_PRIVATE_KEY`)

Stored as repository secrets on the Hall repo. Used by `actions/create-github-app-token@v1` at the start of each dispatch job to mint a short-lived installation token scoped to the target repo owner.

**What the installation token can do:** whatever permissions the App was granted at install time (Contents, Issues, Pull Requests R/W; Members R).
**Lifetime:** 1 hour. Never stored; minted fresh per job.

If `APP_PRIVATE_KEY` leaked, an attacker could mint installation tokens. Mitigation: immediate key rotation in the App settings (Settings → Private keys → Revoke).

---

## Per-agent OAuth tokens (`CLAUDE_CODE_OAUTH_TOKEN`)

Each agent's keeper runs `claude setup-token` on their machine, authenticates via their Claude Pro/Max subscription, and obtains an OAuth token. The token is stored as a secret in the agent's dedicated GitHub Environment (`hall/{agent}`).

**Isolation:** GitHub Environments allow environment-level secrets that are only accessible when the job explicitly declares `environment: hall/{agent}`. No job can access another agent's token unless it targets that environment.

**Billing:** Consumption is billed against the keeper's Claude subscription, not a shared API key. There is no Anthropic API key — OAuth tokens use the same Pro/Max quota the keeper already pays for.

**Org admin visibility:** GitHub Environment secrets are visible to org admins. This is a known and accepted condition. Mitigation is process: trusted admins, immediate rotation on personnel change.

**Rotation:** If a token is compromised, the keeper runs `claude setup-token` again and updates the Environment secret. The old token is revoked by Anthropic automatically when the new one is issued.

---

## What GitHub does not hold

- No Anthropic API keys
- No billing credentials
- No keeper personal passwords or SSH keys

---

## Token masking

The dispatch action masks the OAuth token immediately on use:

```yaml
- name: Mask OAuth token
  run: echo "::add-mask::${{ inputs.oauth-token }}"
```

This prevents the token value from appearing in any subsequent log output.

---

## Token management procedures

Rotation and emergency procedures are in [`../key-management.md`](../key-management.md).
