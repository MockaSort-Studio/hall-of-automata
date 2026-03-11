---
icon: material/skull
---

# Incident Response

What to do when something goes wrong. Three scenarios.

---

## Scenario 1 — Unauthorized invocation attempt

**Symptoms:** A rejection comment appears on the issue from `hall-of-automata[bot]`. The workflow run ended with a failure status. The `@automata-invokers` team was tagged in the comment.

**This is the system working correctly.** The invocation was hard-rejected before any agent ran. No OAuth token was accessed. No usage was counted.

**Actions required:**
- If the user should have access: add them to `automata-invokers` via org admin
- If the attempt was unexpected or suspicious: note it, watch for repeated attempts from the same user, escalate to org admin if pattern continues

No key rotation needed. No workflow changes needed.

---

## Scenario 2 — Exposed OAuth token

**Symptoms:** A token value appearing in logs or a public commit, a security scan alert, unexpected invocations in a keeper's Claude session history, or any reason to believe a token is no longer private.

**Response — act immediately, do not wait:**

1. **Invalidate the old token** — on the keeper's machine run `claude setup-token` again. Issuing a new token automatically invalidates the previous one.
2. **Update the environment secret** — Hall repo → Settings → Environments → `invoker/<handle>` → `CLAUDE_CODE_OAUTH_TOKEN` → update with the new token
3. **Verify** the next invocation succeeds with the new token
4. **Review** Actions logs for the preceding 30 days — look for invocations you did not trigger, unusual timing, or anomalous output
5. **Check** if the token appeared in any commit history — if so, the old value is permanently exposed; the re-issue in step 1 already invalidated it, but investigate the source of the leak

If anomalous usage is confirmed in step 4, treat as Scenario 3.

---

## Scenario 3 — Unauthorized or unexpected automaton output

**Symptoms:** An automaton posts output that was not triggered by a legitimate invocation, produces outputs inconsistent with the issue context, or appears to be acting on instructions from a third party.

This scenario is unlikely given the architecture but is documented for completeness.

**Response:**

1. **Disable the workflow immediately** — add `if: false` to the dispatch job in the relevant workflow file and merge to `main`
2. **Rotate the OAuth token** — follow Scenario 2 steps 1–3
3. **Audit the workflow source** — check git history for recent changes to `.github/workflows/`, particularly any that modified authorization logic or added new steps
4. **Audit Actions logs** — identify every invocation in the preceding period, cross-reference with known legitimate triggers
5. **Report to org admin** — do not attempt to resolve silently

Re-enable the workflow only after the audit is complete and the root cause is identified and resolved.

---

## Contacts

| Role | Contact |
|------|---------|
| Org admin | @mksetaro |
| Hamlet keeper | @mksetaro |

Update this table when the org admin changes or new keepers are added.
