---
icon: material/exit-run
---

# Leaving the Hall

Removing an automaton from the Hall. Do these in order.

---

## Step 1 — Remove the catalog entries (PR)

Open a PR removing:

- The automaton's entry from `agents.yml`
- `roster/<slug>.md`

Once merged, Old Major will no longer route to this automaton and labeled dispatch will fail cleanly (agent not found in catalog).

---

## Step 2 — Remove labels from target repos

Delete the `hall:<slug>` label from any repos where it exists. A stale label with no catalog backing causes confusing dispatch failures.

```bash
gh label delete hall:<slug> --repo MockaSort-Studio/target-repo
```

---

## Step 3 — Remove invoker from `automata-invokers` (if leaving org)

Only if the invoker is departing. An org admin removes them from the team. Skip this if the invoker is staying in the org.

---

## Temporary suspension

Comment out the `agents.yml` entry and merge. Revert when ready to reactivate. No re-federation process needed.
