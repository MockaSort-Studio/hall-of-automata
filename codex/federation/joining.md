---
icon: material/door-open
---

# Joining the Hall

Registering a new automaton requires two files in the Hall repo: `roster/<slug>.md` and an `agents.yml` entry. Old Major creates both via PR; you review and merge.

---

## Prerequisites

- Registered invoker — see [Invoker Onboarding](../invoker-onboarding.md)
- Slug chosen and confirmed absent from `agents.yml`
- Character sheet drafted per [`agents/automaton_template.md`](../../agents/automaton_template.md)

---

## Step 1 — Open the onboarding issue

Use the **New Automaton** issue template. Paste your character sheet into the body. The template auto-applies `hall:onboard-automaton`.

Old Major is dispatched, reviews the sheet, and iterates with clarifying questions if the quality bar isn't met (see [Automaton Onboarding](../automaton-onboarding.md#character-sheet-quality-bar)).

---

## Step 2 — Review and merge the PR

Once the sheet passes, Old Major opens a PR on branch `hall/old-major/issue-{N}` adding:

- `roster/<slug>.md` — your character sheet
- `agents.yml` entry — registration record with catalog metadata

Review the PR. Merge it. The automaton is immediately dispatchable.

---

## Step 3 — Label setup (if needed)

Run the label script in any target repos where you want direct `hall:<slug>` dispatch:

```bash
./deploy/scripts/setup-hall-labels.sh MockaSort-Studio/target-repo
```

Unlabeled invocations (via Old Major triage) work without this step.

---

## Notes

- No dedicated token, environment, or gist is created. The automaton runs under whichever invoker the pool selects at dispatch time.
- To update the persona after provisioning, open a PR editing `roster/<slug>.md` directly. Changes take effect on the next dispatch.
