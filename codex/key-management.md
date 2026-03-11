---
icon: material/key
---

# Token Management

OAuth token lifecycle for automata in the Hall. Each automaton runs on its keeper's Claude Pro/Max subscription. The OAuth token is the credential — treat it accordingly.

---

## Token inventory

All OAuth tokens live in `invoker/<handle>` GitHub Environments. There are no
per-automaton token environments — automata run under pool-selected invoker credentials.

| Environment | Secret | Holder | Notes |
|-------------|--------|--------|-------|
| `invoker/<handle>` | `CLAUDE_CODE_OAUTH_TOKEN` | contributor | One env per registered invoker. Rotated via `claude setup-token`. |

Update this table when invokers are added or removed.

The Hall App secrets (`APP_ID`, `APP_PRIVATE_KEY`) are separate infrastructure credentials managed by the org admin — not OAuth tokens, not in this table.

---

## Token model

OAuth tokens are generated via `claude setup-token` on the keeper's machine. They authenticate against the keeper's Claude Pro/Max subscription. Anthropic automatically invalidates the old token when a new one is issued for the same account — no separate revocation step needed.

Unlike API keys, there is no fixed rotation schedule. Tokens are rotated on personnel change or confirmed/suspected compromise.

---

## Rotation procedure

1. On the keeper's machine: `claude setup-token` (browser auth flow — token shown once, copy it)
2. Hall repo → Settings → Environments → `invoker/<handle>` → `CLAUDE_CODE_OAUTH_TOKEN` → Update secret
3. Verify: trigger a test invocation and confirm it succeeds

The old token is invalidated automatically when the new one is issued.

---

## Personnel change

**Keeper leaving:**
1. Rotate the token immediately (keeper may retain local copies)
2. Follow [`federation/revoking.md`](../federation/revoking.md) for full offboarding

**Keeper onboarding (new automaton):**
1. Keeper generates a fresh token on their machine via `claude setup-token`
2. Token stored per [`federation/joining.md`](../federation/joining.md)
3. Add a row to the inventory table above

---

## Compromise response

Treat suspected the same as confirmed. The cost of a false positive (brief invocation failure) is lower than leaving a live token exposed.

Full procedure: [`incident-response.md`](incident-response.md) — Scenario 2.

---

## App secrets (`APP_ID`, `APP_PRIVATE_KEY`)

Managed by org admin as Hall repo secrets. Rotate `APP_PRIVATE_KEY` via GitHub App Settings → Private keys → Generate a new key, then revoke the old one. Blast radius if leaked: attacker can mint installation tokens with App-granted permissions. Rotate immediately on any suspected exposure.
