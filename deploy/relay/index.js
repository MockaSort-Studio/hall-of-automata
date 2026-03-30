// Hall webhook relay — multi-org federation edition
//
// Env vars:
//   WEBHOOK_SECRET  — HMAC secret for GitHub App webhook
//   APP_ID          — Hall GitHub App ID
//   APP_PRIVATE_KEY — Hall GitHub App private key PEM
//   HALL_OPERATOR   — org that operates Hall (default: MockaSort-Studio)
//   HALL_REPO       — Hall repo name convention (default: hall-of-automata)
//   HALL_REF        — branch to dispatch on (default: main)

import { createServer }                from 'http'
import { createHmac, timingSafeEqual, createSign, createHash } from 'crypto'
import { onboardOrg }                  from './onboard.js'
import { broadcastSync }               from './broadcast.js'
import { HALL_LABELS }                 from './labels.js'

const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET
const APP_ID         = process.env.APP_ID
const APP_PRIVATE_KEY = (process.env.APP_PRIVATE_KEY || '').replace(/\\n/g, '\n')
const HALL_OPERATOR  = process.env.HALL_OPERATOR || 'MockaSort-Studio'
const HALL_REPO      = process.env.HALL_REPO     || 'hall-of-automata'
const HALL_REF       = process.env.HALL_REF      || 'main'

// System labels — not invocation triggers
// hall:old-major is included: old-major is always reached via hall:dispatch-automaton.
// Blocking direct invocation by label prevents the self-loop where old-major
// applies hall:old-major as a routing signal and the relay re-dispatches it.
const SYSTEM_LABELS = new Set([
  'hall:awaiting-input', 'hall:queued', 'hall:invoker-queued',
  'hall:onboard-invoker', 'hall:onboard-automaton', 'hall:active-invoker',
  'hall:old-major',
])

// ── JWT ───────────────────────────────────────────────────────────────────────
function makeJwt() {
  const now = Math.floor(Date.now() / 1000)
  const header  = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url')
  const payload = Buffer.from(JSON.stringify({ iat: now - 60, exp: now + 600, iss: APP_ID })).toString('base64url')
  const sign = createSign('RSA-SHA256')
  sign.update(`${header}.${payload}`)
  return `${header}.${payload}.${sign.sign(APP_PRIVATE_KEY, 'base64url')}`
}

// ── GitHub API helper ─────────────────────────────────────────────────────────
function gh(path, opts = {}, authToken) {
  const token = authToken ?? makeJwt()
  return fetch(`https://api.github.com${path}`, {
    ...opts,
    headers: {
      Authorization:  `Bearer ${token}`,
      Accept:         'application/vnd.github+json',
      'User-Agent':   'hall-relay/2.0',
      'Content-Type': 'application/json',
      ...opts.headers,
    },
    body: opts.body != null ? JSON.stringify(opts.body) : undefined,
  })
}

// ── Installation registry ─────────────────────────────────────────────────────
// Map: installationId (number) → orgLogin (string). Refreshed every 5 minutes.
let installationRegistry = new Map()
let registryRefreshedAt  = 0

async function refreshRegistry() {
  const res = await gh('/app/installations?per_page=100')
  if (!res.ok) { console.error('[relay] registry refresh failed', res.status); return }
  const list = await res.json()
  installationRegistry = new Map(list.map(i => [i.id, i.account.login]))
  registryRefreshedAt  = Date.now()
  console.log(`[relay] registry refreshed — ${installationRegistry.size} installations`)
}

async function ensureRegistry() {
  if (Date.now() - registryRefreshedAt > 5 * 60_000) await refreshRegistry()
}

// ── Per-installation token cache ──────────────────────────────────────────────
const tokenCache = new Map()   // installationId → { token, expiresAt }

export async function getToken(installationId, permissions) {
  const cacheKey = `${installationId}:${JSON.stringify(permissions ?? {})}`
  const cached = tokenCache.get(cacheKey)
  if (cached && Date.now() < cached.expiresAt - 300_000) return cached.token

  const body = permissions ? { permissions } : undefined
const res = await gh(`/app/installations/${installationId}/access_tokens`, { method: 'POST', body })
  if (!res.ok) throw new Error(`token fetch failed: ${res.status} ${await res.text()}`)
  const { token, expires_at } = await res.json()
  tokenCache.set(cacheKey, { token, expiresAt: new Date(expires_at).getTime() })
  return token
}

// ── Per-org rate limiting ─────────────────────────────────────────────────────
const rateLimiter   = new Map()
const RATE_WINDOW   = 60_000   // 1 minute
const RATE_MAX      = 20       // dispatches per window per org

function isRateLimited(installationId) {
  const now   = Date.now()
  const state = rateLimiter.get(installationId) ?? { count: 0, windowStart: now }
  if (now - state.windowStart > RATE_WINDOW) {
    rateLimiter.set(installationId, { count: 1, windowStart: now })
    return false
  }
  if (state.count >= RATE_MAX) return true
  state.count++
  return false
}

// ── Audit log ─────────────────────────────────────────────────────────────────
// Pseudonymise org/repo identifiers for audit logs.
// Deterministic short hash — sufficient for log correlation, not reversible.
function mask(value) {
  if (!value) return undefined
  return createHash('sha256').update(String(value)).digest('hex').slice(0, 10)
}

// Structured JSON to stdout. Never logs payload content or plain org/repo names.
function audit(fields) {
  const safe = { ...fields }
  for (const key of ['org', 'repo-owner', 'repo-name', 'repo']) {
    if (safe[key] != null) safe[key] = mask(safe[key])
  }
  console.log(JSON.stringify({ ts: new Date().toISOString(), ...safe }))
}

// ── Delivery deduplication ────────────────────────────────────────────────────
// X-GitHub-Delivery is a unique UUID per webhook delivery. Track for 5 minutes
// to drop true duplicates (GitHub occasional double-sends) without false positives.
const seenDeliveries = new Map()   // deliveryId → expiresAt
const DELIVERY_TTL   = 5 * 60_000

function isDuplicate(deliveryId) {
  if (!deliveryId) return false
  const now = Date.now()
  if (seenDeliveries.has(deliveryId)) return true
  seenDeliveries.set(deliveryId, now + DELIVERY_TTL)
  // Prune expired entries
  for (const [id, exp] of seenDeliveries) if (now > exp) seenDeliveries.delete(id)
  return false
}

// ── Webhook verification ───────────────────────────────────────────────────────
function verify(rawBody, sig) {
  if (!sig) return false
  const expected = 'sha256=' + createHmac('sha256', WEBHOOK_SECRET).update(rawBody).digest('hex')
  try { return timingSafeEqual(Buffer.from(sig), Buffer.from(expected)) } catch { return false }
}

// ── Cross-verify installation → org ──────────────────────────────────────────
// Guards against payload claiming an org that doesn't match the installation.
function crossVerify(installationId, claimedOrg) {
  const registered = installationRegistry.get(installationId)
  return registered != null && registered.toLowerCase() === claimedOrg.toLowerCase()
}

// ── Dispatch ──────────────────────────────────────────────────────────────────
async function dispatch(org, installationId, inputs, trigger) {
  const token = await getToken(installationId, { actions: 'write' })
  const url   = `https://api.github.com/repos/${org}/${HALL_REPO}/actions/workflows/invoke.yml/dispatches`
  const res   = await fetch(url, {
    method:  'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', 'User-Agent': 'hall-relay/2.0' },
    body:    JSON.stringify({ ref: HALL_REF, inputs }),
  })
  audit({ event: 'dispatch', trigger, org, 'repo-owner': inputs['repo-owner'], 'repo-name': inputs['repo-name'], agent: inputs.agent, status: res.status })
  if (!res.ok) console.error('[relay] dispatch failed', res.status, await res.text())
}

// ── Label seeding ─────────────────────────────────────────────────────────────
export async function seedLabels(org, repo, token) {
  for (const label of HALL_LABELS) {
    const res = await fetch(`https://api.github.com/repos/${org}/${repo}/labels`, {
      method:  'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', 'User-Agent': 'hall-relay/2.0' },
      body:    JSON.stringify(label),
    })
    if (!res.ok && res.status !== 422) {   // 422 = already exists, not an error
      console.warn(`[relay] label seed failed: ${label.name} on ${mask(org)}/${mask(repo)}`, res.status)
    }
  }
  audit({ event: 'labels_seeded', org, repo })
}

// ── HTTP server ───────────────────────────────────────────────────────────────
createServer(async (req, res) => {

  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200).end('ok')
    return
  }

  if (req.method !== 'POST' || req.url !== '/webhook') {
    res.writeHead(404).end()
    return
  }

  const chunks = []
  for await (const chunk of req) chunks.push(chunk)
  const rawBody = Buffer.concat(chunks)

  if (!verify(rawBody, req.headers['x-hub-signature-256'])) {
    console.warn('[relay] rejected — invalid signature')
    return res.writeHead(401).end('Unauthorized')
  }

  // Respond immediately — GitHub retries if response is slow
  res.writeHead(200).end('ok')

  try {
  const deliveryId = req.headers['x-github-delivery']
  if (isDuplicate(deliveryId)) {
    console.warn('[relay] dropped duplicate delivery', deliveryId)
    return
  }

  const event   = req.headers['x-github-event']
  const payload = JSON.parse(rawBody)

  await ensureRegistry()

  // ── installation.created ──────────────────────────────────────────────────
  if (event === 'installation' && payload.action === 'created') {
    const installationId = payload.installation.id
    const org            = payload.installation.account.login
    installationRegistry.set(installationId, org)
    audit({ event: 'installation_created', org, installationId })
    try {
      const token = await getToken(installationId, { actions: 'write', contents: 'write', issues: 'write', members: 'write', administration: 'write' })
      await onboardOrg(org, token, HALL_OPERATOR, HALL_REPO)
    } catch (err) {
      console.error('[relay] onboard failed', mask(org), err.message)
    }
    return
  }

  // ── installation.deleted ──────────────────────────────────────────────────
  if (event === 'installation' && payload.action === 'deleted') {
    const installationId = payload.installation.id
    installationRegistry.delete(installationId)
    tokenCache.delete(installationId)
    audit({ event: 'installation_deleted', org: payload.installation.account.login })
    return
  }

  // ── release.published (operator repo only) ────────────────────────────────
  if (event === 'release' && payload.action === 'published') {
    const org  = payload.repository?.owner?.login
    const repo = payload.repository?.name
    if (org === HALL_OPERATOR && repo === HALL_REPO) {
      const version = payload.release.tag_name
      audit({ event: 'release_published', version })
      broadcastSync(version, installationRegistry, getToken, HALL_OPERATOR).catch(err =>
        console.error('[relay] broadcast failed', err.message)
      )
    }
    return
  }

  // All remaining events require a repository + installation context
  const repoOwner     = payload.repository?.owner?.login
  const repoName      = payload.repository?.name
  const installationId = payload.installation?.id

  if (!repoOwner || !installationId) return

  // ── repository.created — seed labels into new org repos ──────────────────
  if (event === 'repository' && payload.action === 'created') {
    if (installationRegistry.has(installationId)) {
      getToken(installationId)
        .then(token => seedLabels(repoOwner, repoName, token))
        .catch(err  => console.error('[relay] label seed failed', mask(repoOwner), mask(repoName), err.message))
    }
    return
  }

  // Skip events from any org's hall-of-automata repo — invoke.yml handles them natively via
  // GitHub's own triggers (issues.labeled, issue_comment). Routing through relay too would double-fire.
  if (repoName === HALL_REPO) return

  // Validate installation against registry and cross-verify org claim
  if (!crossVerify(installationId, repoOwner)) {
    console.warn('[relay] cross-verify failed', { installationId, org: mask(repoOwner) })
    return
  }

  // Per-org rate limiting
  if (isRateLimited(installationId)) {
    audit({ event: 'rate_limited', org: repoOwner })
    return
  }

  // ── issues.labeled ────────────────────────────────────────────────────────
  if (event === 'issues' && payload.action === 'labeled') {
    const label = payload.label?.name ?? ''
    if (label.startsWith('hall:') && !SYSTEM_LABELS.has(label)) {
      const agent = label === 'hall:dispatch-automaton' ? 'old-major' : label.replace('hall:', '')
      await dispatch(repoOwner, installationId, {
        agent,
        'repo-owner':   repoOwner,
        'repo-name':    repoName,
        'issue-number': String(payload.issue.number),
      }, `issues.labeled:${label}:${payload.sender?.login}`)
    }
    return
  }

  // ── issue_comment.created ─────────────────────────────────────────────────
  if (event === 'issue_comment' && payload.action === 'created') {
    const senderLogin = payload.sender?.login ?? ''
    if (payload.sender?.type === 'Bot' || senderLogin.endsWith('[bot]')) return
    const labels = payload.issue?.labels ?? []
    const body   = payload.comment?.body ?? ''

    // Path A — explicit mention: agent from label, fallback to old-major
    if (body.includes('@hall-of-automata[bot]')) {
      const hallLabel = labels.find(l => l.name.startsWith('hall:') && !SYSTEM_LABELS.has(l.name))
      const agent = hallLabel
        ? (hallLabel.name === 'hall:dispatch-automaton' ? 'old-major' : hallLabel.name.replace('hall:', ''))
        : 'old-major'
      await dispatch(repoOwner, installationId, {
        agent,
        'repo-owner':   repoOwner,
        'repo-name':    repoName,
        'issue-number': String(payload.issue.number),
      }, `comment.path-a:${senderLogin}`)
      return
    }

    // Path B — human reply on awaiting-input issue
    const isAwaiting = labels.some(l => l.name === 'hall:awaiting-input')
    const hallLabel  = labels.find(l => l.name.startsWith('hall:') && !SYSTEM_LABELS.has(l.name))
    if (isAwaiting && hallLabel) {
      const agent = hallLabel.name === 'hall:dispatch-automaton' ? 'old-major' : hallLabel.name.replace('hall:', '')
      await dispatch(repoOwner, installationId, {
        agent,
        'repo-owner':   repoOwner,
        'repo-name':    repoName,
        'issue-number': String(payload.issue.number),
      }, `comment.path-b:${senderLogin}`)
    }
  }
  } catch (err) {
    console.error('[relay] unhandled error processing webhook', err.message)
  }

}).listen(3000, () => {
  console.log('[relay] listening on :3000')
  refreshRegistry().catch(err => console.error('[relay] initial registry load failed', err.message))
})
