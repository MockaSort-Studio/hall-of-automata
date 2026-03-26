// broadcast.js — fires a hall.sync repository_dispatch to all installed orgs.
// Called by index.js on release.published from the Hall operator repo.

const UA = 'hall-relay/2.0'

export async function broadcastSync(version, installationRegistry, getToken) {
  let dispatched = 0
  let failed     = 0

  for (const [installationId, org] of installationRegistry) {
    try {
      const token = await getToken(installationId)
      const res   = await fetch(`https://api.github.com/repos/${org}/hall-of-automata/dispatches`, {
        method:  'POST',
        headers: {
          Authorization:  `Bearer ${token}`,
          Accept:         'application/vnd.github+json',
          'Content-Type': 'application/json',
          'User-Agent':   UA,
        },
        body: JSON.stringify({ event_type: 'hall.sync', client_payload: { version } }),
      })
      if (res.ok) {
        dispatched++
        console.log(`[broadcast] sync ${version} → ${org}`)
      } else {
        failed++
        console.warn(`[broadcast] failed for ${org}`, res.status)
      }
    } catch (err) {
      failed++
      console.warn(`[broadcast] error for ${org}`, err.message)
    }
  }

  console.log(JSON.stringify({
    ts: new Date().toISOString(),
    event: 'broadcast_complete',
    version,
    dispatched,
    failed,
  }))
}
