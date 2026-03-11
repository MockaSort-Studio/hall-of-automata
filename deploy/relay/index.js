// Hall webhook relay — receives GitHub org webhooks and forwards them to
// invoke.yml via workflow_dispatch. Deploy on Fly.io (see fly.toml).
//
// Env vars (set via `fly secrets set`):
//   WEBHOOK_SECRET  — shared secret configured in the GitHub org webhook
//   GITHUB_TOKEN    — fine-grained PAT with actions:write on hall-of-automata
//   HALL_OWNER      — org name (default: MockaSort-Studio)
//   HALL_REPO       — Hall repo name (default: hall-of-automata)
//   HALL_REF        — branch to dispatch on (default: main)

import { createServer } from 'http'
import { createHmac, timingSafeEqual } from 'crypto'

const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET
const GITHUB_TOKEN   = process.env.GITHUB_TOKEN
const HALL_OWNER     = process.env.HALL_OWNER || 'MockaSort-Studio'
const HALL_REPO      = process.env.HALL_REPO  || 'hall-of-automata'
const HALL_REF       = process.env.HALL_REF   || 'main'

// Labels managed by the Hall itself — not invocation triggers
const SYSTEM_LABELS = [
  'hall:awaiting-input',
  'hall:queued',
  'hall:invoker-queued',
  'hall:onboard-invoker',
  'hall:onboard-automaton',
  'hall:active-invoker',
]

function verify(rawBody, sig) {
  if (!sig) return false
  const expected = 'sha256=' + createHmac('sha256', WEBHOOK_SECRET).update(rawBody).digest('hex')
  try { return timingSafeEqual(Buffer.from(sig), Buffer.from(expected)) } catch { return false }
}

async function dispatch(inputs) {
  const url = `https://api.github.com/repos/${HALL_OWNER}/${HALL_REPO}/actions/workflows/invoke.yml/dispatches`
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization:  `Bearer ${GITHUB_TOKEN}`,
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
    // Never process bot comments
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
}).listen(8080, () => console.log('[relay] listening on :8080'))
