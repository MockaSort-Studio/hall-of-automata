# Secrets Model

## What lives where

| Secret | Location | Scope | Purpose |
|--------|----------|-------|---------|
| `APP_ID` | Hall repo secret | Public identifier | GitHub App identity, used to mint installation tokens |
| `APP_PRIVATE_KEY` | Hall repo secret | Signs JWT requests | Generates GitHub App installation tokens |
| `CLAUDE_CODE_OAUTH_TOKEN` | Per-agent GitHub Environment (`hall/{agent}`) | Claude Pro/Max subscription | Agent OAuth credential, billed to keeper's subscription |

The GitHub App private key and App ID are Hall-level infrastructure secrets. Agent OAuth tokens are isolated per-agent in dedicated Environments.

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

## Key management procedures

Rotation schedule and emergency procedures are in [`codex/key-management.md`](../codex/key-management.md). That document predates the OAuth model — the principles apply but the token type is now OAuth, not API key.
