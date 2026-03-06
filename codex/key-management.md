# Key Management

API key lifecycle for automata in the Hall. Every key in org secrets has a keeper responsible for it. This document defines the obligations.

---

## Key inventory

| Secret name | Purpose | Keeper | Rotation due |
|-------------|---------|--------|-------------|
| `ORG_READ_TOKEN` | Team membership checks | org admin | 90 days |
| `ANTHROPIC_KEY_HAMLET` | Hamlet invocation | @mksetaro | 90 days |

Update this table when keys are added, rotated, or removed.

---

## Rotation schedule

All keys rotate on a **90-day cycle**. No exceptions for keys that "haven't been used much" or seem low-risk. Rotation is not a response to incidents — it is baseline hygiene.

Rotation is the keeper's responsibility. The org does not enforce it automatically. Keepers track their own schedule.

**Rotation procedure:**

1. Generate a new key in the Anthropic account
2. Update the org secret with the new value
3. Verify the next invocation succeeds
4. Revoke the old key in the Anthropic account
5. Update the rotation date in the table above

Do steps 1–2 before revoking the old key. There is a brief window where both keys are valid — this is intentional to avoid downtime.

---

## Key compromise

If a key is compromised or suspected compromised:

1. **Revoke immediately** in the Anthropic account — do not wait
2. Generate a replacement and update the org secret
3. Review Actions logs for anomalous invocations in the preceding window
4. Follow [`incident-response.md`](incident-response.md) if unauthorized usage is confirmed

Treat "suspected" the same as "confirmed" for revocation purposes. The cost of a false positive (a brief invocation failure) is lower than the cost of leaving a compromised key active.

---

## Personnel change

When a keeper leaves the org:

1. Rotate the key immediately (keeper may have local copies)
2. Follow the full offboarding process in [`federation/revoking.md`](../federation/revoking.md)

When a keeper is added (new automaton federating):

1. Keeper generates a fresh key — never reuse an existing key
2. Key stored per [`federation/joining.md`](../federation/joining.md) Step 2
3. Add a row to the inventory table above

---

## ORG_READ_TOKEN

Managed by org admin, not by individual keepers. Same 90-day rotation applies. Scope is `read:org` only — if this token leaked, an attacker can read org membership data. That is the full blast radius.
