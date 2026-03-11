// Hall webhook relay — receives GitHub org webhooks and forwards them to
// invoke.yml via workflow_dispatch. Deploy on Fly.io (see fly.toml).
//
// Env vars (set via `fly secrets set`):
//   WEBHOOK_SECRET  — shared secret configured in the GitHub org webhook
//   APP_ID          — Hall GitHub App ID (same as in Hall repo secrets)
//   APP_PRIVATE_KEY — Hall GitHub App private key PEM (same as in Hall repo secrets)
//   HALL_OWNER      — org name (default: MockaSort-Studio)
//   HALL_REPO       — Hall repo name (default: hall-of-automata)
//   HALL_REF        — branch to dispatch on (default: main)

import { createServer } from 'http'
import { createHmac, timingSafeEqual, createSign } from 'crypto'

const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET
const APP_ID         = process.env.APP_ID
const APP_PRIVATE_KEY = (process.env.APP_PRIVATE_KEY || '').replace(/\\n/g, '\n')
const HALL_OWNER     = process.env.HALL_OWNER || 'MockaSort-Studio'
const HALL_REPO      = process.env.HALL_REPO  || 'hall-of-automata'
const HALL_REF       = process.env.HALL_REF   || 'main'

// System labels managed by the Hall — not invocation triggers
const SYSTEM_LABELS = [
  'hall:awaiting-input',
  'hall:queued',
  'hall:invoker-queued',
  'hall:onboard-invoker',
  'hall:onboard-automaton',
  'hall:active-invoker',
]

// ── GitHub App token generation ───────────────────────────────────────────────
// Tokens expire after 1 hour. Cache and refresh when within 5 minutes of expiry.
let cachedToken = null
let tokenExpiresAt = 0

function makeJwt() {
  const now = Math.floor(Date.now() / 1000)
  const header  = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url')
  const payload = Buffer.from(JSON.stringify({ iat: now - 60, exp: now + 600, iss: APP_ID })).toString('base64url')
  const sign = createSign('RSA-SHA256')
  sign.update(`${header}.${payload}`)
  const sig = sign.sign(APP_PRIVATE_KEY, 'base64url')
  return `${header}.${payload}.${sig}`
}

async function getInstallationToken() {
  if (cachedToken && Date.now() < tokenExpiresAt - 300_000) return cachedToken

  // 1. Get the installation ID for HALL_OWNER
  const jwt = makeJwt()
  const instRes = await fetch(`https://api.github.com/orgs/${HALL_OWNER}/installation`, {
    headers: { Authorization: `Bearer ${jwt}`, Accept: 'application/vnd.github+json', 'User-Agent': 'hall-relay/1.0' },
  })
  if (!instRes.ok) throw new Error(`Failed to get installation: ${instRes.status} ${await instRes.text()}`)
  const { id: installationId } = await instRes.json()

  // 2. Exchange for an installation access token
  const tokRes = await fetch(`https://api.github.com/app/installations/${installationId}/access_tokens`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${jwt}`, Accept: 'application/vnd.github+json', 'User-Agent': 'hall-relay/1.0' },
  })
  if (!tokRes.ok) throw new Error(`Failed to get access token: ${tokRes.status} ${await tokRes.text()}`)
  const { token, expires_at } = await tokRes.json()

  cachedToken = token
  tokenExpiresAt = new Date(expires_at).getTime()
  console.log('[relay] refreshed installation token, expires', expires_at)
  return token
}

// ── Webhook verification ───────────────────────────────────────────────────────
function verify(rawBody, sig) {
  if (!sig) return false
  const expected = 'sha256=' + createHmac('sha256', WEBHOOK_SECRET).update(rawBody).digest('hex')
  try { return timingSafeEqual(Buffer.from(sig), Buffer.from(expected)) } catch { return false }
}

// ── Dispatch ──────────────────────────────────────────────────────────────────
async function dispatch(inputs) {
  const token = await getInstallationToken()
  const url = `https://api.github.com/repos/${HALL_OWNER}/${HALL_REPO}/actions/workflows/invoke.yml/dispatches`
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization:  `Bearer ${token}`,
      'Content-Type': 'application/json',
      'User-Agent':   'hall-relay/1.0',
    },
    body: JSON.stringify({ ref: HALL_REF, inputs }),
  })
  if (!res.ok) {
    console.error('[relay] dispatch failed', res.status, await res.text())
  } else {
    const { agent, 'repo-owner': owner, 'repo-name': repo, 'issue-number': num } = inputs
    console.log(`[relay] dispatched agent=${agent} target=${owner}/${repo}#${num}`)
  }
}

// ── HTTP server ───────────────────────────────────────────────────────────────
createServer(async (req, res) => {
  if (req.method !== 'POST' || req.url !== '/webhook') {
    res.writeHead(404).end()
    return
  }

  const chunks = []
  for await (const chunk of req) chunks.push(chunk)
  const rawBody = Buffer.concat(chunks)

  if (!verify(rawBody, req.headers['x-hub-signature-256'])) {
    console.warn('[relay] rejected — invalid signature')
    res.writeHead(401).end('Unauthorized')
    return
  }

  const event   = req.headers['x-github-event']
  const payload = JSON.parse(rawBody)
  const repoOwner = payload.repository?.owner?.login
  const repoName  = payload.repository?.name

  // issues.labeled — standard invocation trigger
  if (event === 'issues' && payload.action === 'labeled') {
    const label = payload.label?.name || ''
    if (label.startsWith('hall:') && !SYSTEM_LABELS.includes(label)) {
      const agent = label === 'hall:dispatch-automaton' ? 'old-major' : label.replace('hall:', '')
      await dispatch({
        agent,
        'repo-owner':   repoOwner,
        'repo-name':    repoName,
        'issue-number': String(payload.issue.number),
      })
    }
  }

  // issue_comment.created — awaiting-input reply re-dispatch
  if (event === 'issue_comment' && payload.action === 'created') {
    if (payload.sender?.type === 'Bot') { res.writeHead(200).end('ok'); return }
    const labels    = payload.issue?.labels || []
    const hallLabel = labels.find(l => l.name.startsWith('hall:') && !SYSTEM_LABELS.includes(l.name))
    if (hallLabel) {
      const agent = hallLabel.name === 'hall:dispatch-automaton' ? 'old-major' : hallLabel.name.replace('hall:', '')
      await dispatch({
        agent,
        'repo-owner':   repoOwner,
        'repo-name':    repoName,
        'issue-number': String(payload.issue.number),
      })
    }
  }

  res.writeHead(200).end('ok')
}).listen(3000, () => console.log('[relay] listening on :3000'))
