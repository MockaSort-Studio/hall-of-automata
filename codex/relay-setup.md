---
icon: material/webhook
---

# Webhook Relay — Fly.io Setup

The Hall only sees events from its own repository. The webhook relay extends it to the entire org: a lightweight HTTP server on Fly.io receives GitHub org-level webhooks and forwards them to `invoke.yml` via `workflow_dispatch`.

Once deployed, any repo in the org can use Hall agents by labeling issues — no need to open issues in `hall-of-automata` manually.

---

## Architecture

```
GitHub org webhook (any repo)
  └─▶ hall-relay.fly.dev/webhook
        ├─ validate HMAC-SHA256 signature
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

- [flyctl](https://fly.io/docs/hands-on/install-flyctl/) installed and authenticated
- A Fly.io account (free tier is sufficient)
- A GitHub fine-grained PAT or GitHub App token with `actions: write` on `hall-of-automata`

---

## 1. Create the relay app

```bash
mkdir hall-relay && cd hall-relay
fly launch --name hall-relay --region lhr --no-deploy
```

Create two files:

=== "index.js"

    ```js
    import { createServer } from 'http'
    import { createHmac, timingSafeEqual } from 'crypto'

    const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET
    const GITHUB_TOKEN   = process.env.GITHUB_TOKEN
    const HALL_OWNER     = process.env.HALL_OWNER || 'MockaSort-Studio'
    const HALL_REPO      = process.env.HALL_REPO  || 'hall-of-automata'
    const HALL_REF       = process.env.HALL_REF   || 'main'

    const SYSTEM_LABELS = [
      'hall:awaiting-input', 'hall:queued', 'hall:invoker-queued',
      'hall:onboard-invoker', 'hall:onboard-automaton', 'hall:active-invoker',
    ]

    function verify(body, sig) {
      if (!sig) return false
      const expected = 'sha256=' + createHmac('sha256', WEBHOOK_SECRET).update(body).digest('hex')
      try { return timingSafeEqual(Buffer.from(sig), Buffer.from(expected)) } catch { return false }
    }

    async function dispatch(inputs) {
      const res = await fetch(
        `https://api.github.com/repos/${HALL_OWNER}/${HALL_REPO}/actions/workflows/invoke.yml/dispatches`,
        {
          method: 'POST',
          headers: { Authorization: `Bearer ${GITHUB_TOKEN}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ ref: HALL_REF, inputs }),
        }
      )
      if (!res.ok) console.error('dispatch failed', res.status, await res.text())
      else console.log('dispatched', inputs.agent, 'for', inputs['repo-owner'] + '/' + inputs['repo-name'], '#' + inputs['issue-number'])
    }

    createServer(async (req, res) => {
      if (req.method !== 'POST' || req.url !== '/webhook') {
        res.writeHead(404).end(); return
      }

      const chunks = []
      for await (const chunk of req) chunks.push(chunk)
      const rawBody = Buffer.concat(chunks)

      if (!verify(rawBody, req.headers['x-hub-signature-256'])) {
        console.warn('invalid signature')
        res.writeHead(401).end('Unauthorized'); return
      }

      const event   = req.headers['x-github-event']
      const payload = JSON.parse(rawBody)
      const repoOwner = payload.repository?.owner?.login
      const repoName  = payload.repository?.name

      if (event === 'issues' && payload.action === 'labeled') {
        const label = payload.label?.name || ''
        if (label.startsWith('hall:') && !SYSTEM_LABELS.includes(label)) {
          const agent = label === 'hall:dispatch-automaton' ? 'old-major' : label.replace('hall:', '')
          await dispatch({ agent, 'repo-owner': repoOwner, 'repo-name': repoName,
                           'issue-number': String(payload.issue.number) })
        }
      }

      if (event === 'issue_comment' && payload.action === 'created') {
        if (payload.sender?.type === 'Bot') { res.writeHead(200).end('ok'); return }
        const labels    = payload.issue?.labels || []
        const hallLabel = labels.find(l => l.name.startsWith('hall:') && !SYSTEM_LABELS.includes(l.name))
        if (hallLabel) {
          const agent = hallLabel.name === 'hall:dispatch-automaton' ? 'old-major' : hallLabel.name.replace('hall:', '')
          await dispatch({ agent, 'repo-owner': repoOwner, 'repo-name': repoName,
                           'issue-number': String(payload.issue.number) })
        }
      }

      res.writeHead(200).end('ok')
    }).listen(8080)
    ```

=== "package.json"

    ```json
    { "type": "module", "engines": { "node": ">=22" } }
    ```

Update the generated `fly.toml` to ensure:

```toml
[http_service]
  internal_port = 8080
  force_https   = true
```

---

## 2. Set secrets

```bash
# Generate a random webhook secret — save this for the next step
WEBHOOK_SECRET=$(openssl rand -hex 32)
echo "Webhook secret: $WEBHOOK_SECRET"

fly secrets set \
  WEBHOOK_SECRET="$WEBHOOK_SECRET" \
  GITHUB_TOKEN="<fine-grained PAT: actions:write on hall-of-automata>" \
  HALL_OWNER="MockaSort-Studio" \
  HALL_REPO="hall-of-automata"
```

The PAT needs only `actions: write` on `hall-of-automata` — nothing else. A fine-grained token scoped to that single repo is sufficient.

---

## 3. Deploy

```bash
fly deploy
```

Note the URL printed at the end: `https://hall-relay.fly.dev`.

---

## 4. Register the org webhook

Go to **GitHub → MockaSort-Studio org → Settings → Webhooks → Add webhook**:

| Field | Value |
|---|---|
| Payload URL | `https://hall-relay.fly.dev/webhook` |
| Content type | `application/json` |
| Secret | the `WEBHOOK_SECRET` from step 2 |
| Events | Individual: **Issues**, **Issue comments** |
| Active | ✓ |

One org-level webhook covers all repos automatically.

---

## 5. Install the GitHub App on target repos

The Hall App needs permission to push branches and open PRs in each target repo. Go to:

```
https://github.com/apps/hall-of-automata → Configure → Repository access
```

Add each repo, or select **All repositories** for org-wide access.

---

## Cross-repo flow after setup

```
User opens issue in other-repo
  → applies hall:dispatch-automaton (or uses the issue template)
  → org webhook fires
  → relay validates signature, extracts repo + issue
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

Failed dispatches are logged with status code and response body. The relay itself is stateless — a redeploy restores full operation.
