---
icon: material/webhook
---

# Webhook Relay — Fly.io Setup

The Hall only sees events from its own repository. The webhook relay extends it to the entire org: a lightweight HTTP server on Fly.io receives GitHub App webhooks and forwards them to `invoke.yml` via `workflow_dispatch`.

Once deployed, any repo in the org can use Hall agents by labeling issues — no need to open issues in `hall-of-automata` manually.

---

## Why the App webhook, not an org webhook?

The Hall GitHub App is already installed org-wide. GitHub App webhooks fire for every repository where the app is installed — exactly the same scope as a manually configured org webhook, but without the extra setup. You configure the relay URL once in the App settings and reuse the App's webhook secret (`WEBHOOK_SECRET`) that you already have.

No separate org-level webhook is needed.

---

## Architecture

```
GitHub App webhook (any repo where App is installed)
  └─▶ hall-relay.fly.dev/webhook
        ├─ validate HMAC-SHA256 signature (App webhook secret)
        ├─ generate GitHub App installation token (hall-of-automata[bot])
        ├─ filter hall: label events
        └─▶ POST /repos/MockaSort-Studio/hall-of-automata/actions/workflows/invoke.yml/dispatches
              └─▶ [Hall] Invoke Agent (agent, repo-owner, repo-name, issue-number)
```

Events forwarded:

| GitHub event | Condition | Result |
|---|---|---|
| `issues.labeled` | label starts with `hall:` | dispatch agent |
| `issue_comment.created` | issue has `hall:<agent>` label, sender is human | re-dispatch (awaiting-input reply) |

---

## Prerequisites

- [flyctl](https://fly.io/docs/hands-on/install-flyctl/) installed and authenticated (`fly auth login`)
- A Fly.io account (free tier is sufficient)
- The Hall GitHub App `APP_ID`, `APP_PRIVATE_KEY`, and **App webhook secret** (the secret set in the App's Webhook settings page)

---

## 1. Create the relay app

The relay code lives in [`deploy/relay/`](../deploy/relay/) in the Hall repo — no extra files to create.

```bash
cd deploy/relay
fly launch --name hall-relay --region lhr --no-deploy --copy-config
```

The folder already contains `index.js`, `package.json`, and `fly.toml`. The app listens on port 3000 and authenticates as `hall-of-automata[bot]` by generating short-lived installation tokens from the App credentials — no personal token required.

---

## 2. Set secrets

```bash
fly secrets set \
  WEBHOOK_SECRET="<App webhook secret from GitHub App settings>" \
  APP_ID="<Hall GitHub App ID>" \
  APP_PRIVATE_KEY="$(cat path/to/hall-of-automata.private-key.pem)" \
  HALL_OWNER="MockaSort-Studio" \
  HALL_REPO="hall-of-automata"
```

`WEBHOOK_SECRET` is the secret you set (or will set) in **GitHub App → Settings → Webhook → Secret**.
`APP_ID` and `APP_PRIVATE_KEY` are the same values stored as secrets in the Hall repo. The relay generates 1-hour installation tokens and refreshes them automatically (5 min before expiry).

---

## 3. Deploy

```bash
# From repo root — checks for missing secrets before deploying
bash deploy/relay/deploy.sh
```

Or manually from `deploy/relay/`:

```bash
fly deploy
```

Note the URL printed at the end: `https://hall-relay.fly.dev`.

---

## 4. Configure the GitHub App webhook

Go to **GitHub → Developer settings → GitHub Apps → hall-of-automata → Edit**:

| Field | Value |
|---|---|
| Webhook URL | `https://hall-relay.fly.dev/webhook` |
| Webhook secret | a strong random secret (save this — you'll need it for step 2 above) |
| Events | **Issues** + **Issue comments** |
| Active | ✓ |

The App already has the right installation scope — no org webhook needed.

To generate a webhook secret if you don't have one:

```bash
openssl rand -hex 32
```

---

## 5. Ensure the GitHub App is installed on target repos

The Hall App needs permission to push branches and open PRs in each target repo. Go to:

```
https://github.com/apps/hall-of-automata → Configure → Repository access
```

Add each repo, or select **All repositories** for org-wide access. Repos without the app installed will not receive webhook events.

---

## Cross-repo flow after setup

```
User opens issue in other-repo
  → applies hall:dispatch-automaton (or uses the issue template)
  → App webhook fires (because app is installed on other-repo)
  → relay validates signature, generates App token, extracts repo + issue
  → workflow_dispatch → [Hall] Invoke Agent
  → Old Major reads issue, picks specialist, applies hall:<agent>
  → specialist dispatched with repo-owner=other-repo, repo-name=other-repo
  → agent pushes branch + opens PR in other-repo
```

---

## Monitoring

```bash
# Live logs
fly logs --app hall-relay

# App status
fly status --app hall-relay
```

Failed dispatches are logged with status code and response body. The relay is stateless — a redeploy restores full operation.
