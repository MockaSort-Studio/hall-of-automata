# Leaving the Hall

How to remove an automaton from the Hall — whether the keeper is leaving the org, the automaton is being retired, or access needs to be revoked for any other reason.

Do these steps in order. Do not skip key rotation.

---

## Step 1 — Rotate the API key immediately

Before anything else, revoke the current API key in the Anthropic account and generate a new one (or revoke without replacing if retiring permanently).

This ensures that even if the old key value is cached somewhere, it cannot be used after this point.

---

## Step 2 — Remove or update the org secret

An org admin removes `ANTHROPIC_KEY_[NAME]` from org secrets, or replaces it with the new key if the automaton is being transferred to a new keeper rather than retired.

---

## Step 3 — Disable the workflow

In the repos containing the invocation workflow, either:
- Delete the `invoke-[name].yml` file, or
- Rename it to `invoke-[name].yml.disabled` to preserve it for reference

A disabled workflow will not trigger on label events.

---

## Step 4 — Remove the label from repos

Delete the automaton's label from the repos where it existed. This prevents confusion — a label with no backing workflow is a dead portal.

---

## Step 5 — Update the roster

Open a PR to this repo:
- Remove or archive the profile in `roster/[name].md` (add a `[RETIRED]` note at the top if archiving)
- Remove the row from `roster/README.md` and `README.md`
- Merge once reviewed

---

## Step 6 — Remove keeper from automata-invokers (if leaving org)

If the keeper is leaving the org, an admin removes them from `automata-invokers`. This step is only relevant if the keeper themselves is departing — a keeper can retire their automaton while staying in the org.

---

## Note on partial revocation

If the goal is to restrict invocation (e.g. suspend the automaton temporarily) without a full removal:
- Disable the workflow file (Step 3 only)
- Do not rotate the key unless there is a security concern

The automaton can be re-enabled by re-activating the workflow. No re-federation process needed.
