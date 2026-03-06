# Incident Response

What to do when something goes wrong. Three scenarios, three response tracks.

---

## Scenario 1 — Unauthorized invocation attempt

**Symptoms:** An issue comment appears saying a user was denied invocation. Actions log shows a job that exited at the auth check.

**This is the system working correctly.** The label was removed, the user was notified, no API call was made.

**Actions required:**
- If the user should have access: add them to `automata-invokers` via org admin
- If the attempt was unexpected or suspicious: note it, watch for repeated attempts from the same user, escalate to org admin if pattern continues

No key rotation needed. No workflow changes needed.

---

## Scenario 2 — Leaked API key

**Symptoms:** Unexpected Anthropic usage in a keeper's account, a key value appearing in logs or a public commit, a security scan alert, or any reason to believe a key value is no longer private.

**Response — act immediately, do not wait:**

1. **Revoke the key** in the Anthropic account dashboard
2. **Generate a replacement key**
3. **Update the org secret** with the new key
4. **Verify** the next invocation succeeds with the new key
5. **Review** Actions logs for the preceding 30 days — look for invocations you did not trigger, unusual timing, or anomalous output
6. **Check** if the key appeared in any commit history — if it did, the history is compromised and the old key value should be considered permanently exposed regardless of rotation

If anomalous usage is confirmed in step 5, treat as Scenario 3.

---

## Scenario 3 — Unauthorized or unexpected automaton output

**Symptoms:** An automaton posts output that was not triggered by a legitimate invocation, produces outputs inconsistent with the issue context, or appears to be acting on instructions from a third party.

This scenario is unlikely given the architecture but is documented for completeness.

**Response:**

1. **Disable the workflow immediately** — rename `invoke-[name].yml` to `invoke-[name].yml.disabled` on `main`
2. **Rotate the API key** — follow Scenario 2 steps 1–4
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
