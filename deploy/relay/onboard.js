// onboard.js — runs once per new org installation.
// Called by index.js on installation.created with an installation-scoped token.

import sodium from 'libsodium-wrappers'
import { HALL_LABELS } from './labels.js'

// Encrypt a secret value using GitHub's required sealed-box algorithm.
// publicKeyB64: Base64-encoded Curve25519 public key from the secrets API.
async function sealSecret(publicKeyB64, value) {
  await sodium.ready
  const key       = sodium.from_base64(publicKeyB64, sodium.base64_variants.ORIGINAL)
  const message   = Buffer.from(value)
  const encrypted = sodium.crypto_box_seal(message, key)
  return Buffer.from(encrypted).toString('base64')
}

const UA = 'hall-relay/2.0'

function api(token) {
  return async (path, opts = {}) => {
    const res = await fetch(`https://api.github.com${path}`, {
      ...opts,
      headers: {
        Authorization:  `Bearer ${token}`,
        Accept:         'application/vnd.github+json',
        'User-Agent':   UA,
        'Content-Type': 'application/json',
        ...opts.headers,
      },
      body: opts.body != null ? JSON.stringify(opts.body) : undefined,
    })
    return res
  }
}

export async function onboardOrg(org, token, hallOperator, hallRepo, appId, appPrivateKey) {
  const gh = api(token)

  // 1. Create hall-of-automata from template ─────────────────────────────────
  const repoRes = await gh(`/repos/${hallOperator}/${hallRepo}/generate`, {
    method: 'POST',
    body:   { owner: org, name: hallRepo, include_all_branches: false, private: false },
  })
  // 422 = repo already exists — not an error
  if (!repoRes.ok && repoRes.status !== 422) {
    const text = await repoRes.text()
    throw new Error(`repo create failed for ${org}: ${repoRes.status} ${text}`)
  }
  console.log(`[onboard] ${org}/${hallRepo} created`)

  // 2. Create automata-invokers team ─────────────────────────────────────────
  const teamRes = await gh(`/orgs/${org}/teams`, {
    method: 'POST',
    body:   { name: 'automata-invokers', description: 'Hall of Automata invoker pool', privacy: 'closed' },
  })
  if (!teamRes.ok && teamRes.status !== 422) {
    console.warn(`[onboard] team create failed for ${org}`, teamRes.status)
  }

  // 3. Ensure .github repo exists ────────────────────────────────────────────
  const dotGhCheck = await gh(`/repos/${org}/.github`)
  if (dotGhCheck.status === 404) {
    const dotGhRes = await gh(`/orgs/${org}/repos`, {
      method: 'POST',
      body:   { name: '.github', description: 'Org-wide defaults', private: false, auto_init: true },
    })
    if (!dotGhRes.ok) {
      console.warn(`[onboard] .github repo create failed for ${org}`, dotGhRes.status)
    } else {
      // Brief pause for repo to initialise before committing to it
      await new Promise(r => setTimeout(r, 2000))
    }
  }

  // 4. Seed issue templates from operator repo ────────────────────────────────
  // Fetched unauthenticated — operator repo is public
  const templatesRes = await fetch(
    `https://api.github.com/repos/${hallOperator}/${hallRepo}/contents/.github/ISSUE_TEMPLATE`,
    { headers: { Accept: 'application/vnd.github+json', 'User-Agent': UA } }
  )
  if (templatesRes.ok) {
    const templates = await templatesRes.json()
    for (const tpl of Array.isArray(templates) ? templates : []) {
      if (!tpl.download_url) continue
      const raw = await fetch(tpl.download_url)
      if (!raw.ok) continue
      const content = await raw.text()
      const putRes = await gh(`/repos/${org}/.github/contents/.github/ISSUE_TEMPLATE/${tpl.name}`, {
        method: 'PUT',
        body:   { message: `chore: seed Hall issue template — ${tpl.name}`, content: Buffer.from(content).toString('base64') },
      })
      if (!putRes.ok) console.warn(`[onboard] template seed failed: ${tpl.name} → ${org}`, putRes.status)
    }
    console.log(`[onboard] issue templates seeded for ${org}`)
  }

  // 5. Seed Hall labels into hall-of-automata ────────────────────────────────
  // Wait briefly for the templated repo to be fully ready
  await new Promise(r => setTimeout(r, 3000))
  for (const label of HALL_LABELS) {
    const res = await gh(`/repos/${org}/${hallRepo}/labels`, { method: 'POST', body: label })
    if (!res.ok && res.status !== 422) {
      console.warn(`[onboard] label seed failed: ${label.name} on ${org}/${hallRepo}`, res.status)
    }
  }
  console.log(`[onboard] labels seeded for ${org}/${hallRepo}`)

  // 6. Seed APP_ID + APP_PRIVATE_KEY as org secrets scoped to hall-of-automata ─
  // Stored at org level (not repo level) so only org admins can manage them.
  // Requires organization_secrets:write App permission.
  if (appId && appPrivateKey) {
    try {
      const pkRes  = await gh(`/orgs/${org}/actions/secrets/public-key`)
      const { key: pubKey, key_id } = await pkRes.json()

      const repoIdRes = await gh(`/repos/${org}/${hallRepo}`)
      const { id: repoId } = await repoIdRes.json()

      const putSecret = async (name, value) => {
        const encrypted_value = await sealSecret(pubKey, value)
        const res = await gh(`/orgs/${org}/actions/secrets/${name}`, {
          method: 'PUT',
          body:   { encrypted_value, key_id, visibility: 'selected', selected_repository_ids: [repoId] },
        })
        if (!res.ok) console.warn(`[onboard] secret seed failed: ${name} for ${org}`, res.status)
      }

      await putSecret('APP_ID', String(appId))
      await putSecret('APP_PRIVATE_KEY', appPrivateKey)
      console.log(`[onboard] org secrets seeded for ${org}`)
    } catch (err) {
      console.warn(`[onboard] org secret seeding failed for ${org}`, err.message)
    }
  }

  // 7. Open welcome issue ────────────────────────────────────────────────────
  const issueBody = `\
# Welcome to Hall of Automata

Your Hall instance is ready. Follow these steps to go live.

## Step 1 — Generate your Claude OAuth token

See the [token generation guide](https://github.com/${hallOperator}/${hallRepo}/blob/main/codex/generate-token.md) \
for instructions on macOS, Linux, and Windows.

## Step 2 — Add your first invoker

Label this issue \`hall:onboard-invoker\` to begin the invoker registration flow. \
The Hall will guide you through adding your Claude token as invoker quota.

## Step 3 — Provision Old Major

Once you have an active invoker, open a new issue using the **New Automaton** template \
and submit Old Major's character sheet. He will self-provision as your Hall Master.

## Step 4 — Invoke automata in any org repo

Apply \`hall:dispatch-automaton\` or \`hall:<agent>\` labels to issues in any repo \
in this organisation. The Hall relay routes the event to your instance automatically.

---

## ⚠️ Security note for org admins

Two org-level secrets have been created in your organisation: \`APP_ID\` and \`APP_PRIVATE_KEY\`. \
These are the Hall GitHub App credentials that allow your workflows to authenticate. They are:

- Scoped exclusively to this repository — no other repo in your org can access them
- Managed at the **org level** — only org admins can view or modify them

**Do not delete, rotate, or modify these secrets** unless you are coordinating a key rotation with the Hall operator. \
Removing them will cause all Hall workflows in this org to fail.

---
*Provisioned by Hall Relay · ${new Date().toISOString().split('T')[0]}*`

  const issueRes = await gh(`/repos/${org}/${hallRepo}/issues`, {
    method: 'POST',
    body:   { title: 'Hall of Automata — Getting Started', body: issueBody, labels: ['hall:onboard-invoker'] },
  })
  if (!issueRes.ok) {
    console.warn(`[onboard] welcome issue failed for ${org}`, issueRes.status)
  } else {
    console.log(`[onboard] welcome issue opened for ${org}`)
  }
}
