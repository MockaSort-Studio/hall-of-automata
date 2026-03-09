---
icon: material/exit-run
---

# Leaving the Hall

How to remove an automaton from the Hall — whether the keeper is departing, the automaton is being retired, or access needs to be revoked for any other reason.

Do these steps in order. Rotate the token first, always.

---

## Step 1 — Rotate or revoke the OAuth token immediately

On the keeper's machine, issue a new token via `claude setup-token`. This automatically invalidates the old token.

If retiring permanently (no replacement), work with an org admin to delete or empty the `CLAUDE_CODE_OAUTH_TOKEN` secret. The old token is already invalidated by re-issuing.

---

## Step 2 — Disable the environment

An org admin disables the `hall/{name}` GitHub Environment or removes/replaces the `CLAUDE_CODE_OAUTH_TOKEN` secret. With the secret absent or invalid, invocations fail at the dispatch step.

For a full retirement, the admin deletes the environment after running the workflow disable in Step 3.

---

## Step 3 — Disable the dispatch workflow

Set the agent's dispatch workflow to `if: false` on the relevant job to prevent any further runs. For a temporary suspension this is enough — revert when ready to reactivate.

For a full retirement, open a PR removing the workflow file entirely.

---

## Step 4 — Remove the label from repos

Delete the `hall:{name}` label from any repos where it exists. A label with no backing workflow is a dead portal — remove it to avoid confusion.

---

## Step 5 — Update the catalog and registration

**Catalog** (admin removes the entry from the `hall/roster` deployment payload):

Remove the automaton's JSON object from the catalog array and create a new deployment with the updated payload. Old Major will no longer route to this automaton.

**`agents.yml` PR** (you open):
- Remove or comment out the automaton's entry
- Remove the row from `roster/README.md` and root `README.md`
- Merge once reviewed

---

## Step 6 — Remove keeper from `automata-invokers` (if leaving org)

Only applies if the keeper is departing. An org admin removes them from the team. This step is not needed when a keeper retires their automaton while staying in the org.

---

## Partial revocation (temporary suspension)

To suspend without full removal:
- Disable the dispatch workflow (`if: false` on the dispatch job) — Step 3 only
- Do not rotate the token unless there is a security concern

Reactivate by reverting the `if: false` change. No re-federation process needed.
