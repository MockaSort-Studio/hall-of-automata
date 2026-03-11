---
icon: material/office-building-cog
---

# Org-Wide Setup

Provisioning a new org with issue templates and Hall labels, so any repo can invoke automata without manual configuration.

---

## Issue templates

GitHub serves community health files from the org's `.github` repository. Templates placed there appear in every repo in the org that doesn't override them with its own `ISSUE_TEMPLATE/`.

### Create the `.github` repo (if it doesn't exist)

```bash
gh repo create MockaSort-Studio/.github --public --description "Org-wide community health files"
git clone https://github.com/MockaSort-Studio/.github
cd .github && mkdir -p .github/ISSUE_TEMPLATE
```

### Copy templates from the Hall repo

```bash
# From the cloned .github repo
HALL=../hall-of-automata  # adjust path if needed

cp $HALL/.github/ISSUE_TEMPLATE/automaton-task.yml      .github/ISSUE_TEMPLATE/
cp $HALL/.github/ISSUE_TEMPLATE/invoker-onboarding.yml  .github/ISSUE_TEMPLATE/
cp $HALL/.github/ISSUE_TEMPLATE/new-automaton.yml       .github/ISSUE_TEMPLATE/

git add . && git commit -m "add Hall issue templates org-wide" && git push
```

Templates are now available in every org repo. When a repo has its own `ISSUE_TEMPLATE/` folder, GitHub shows both sets — the org-level templates do not override repo-local ones.

---

## Labels

GitHub has no native org-wide label sync. Use the script below to create (or update) all Hall labels in one or more repos.

The script lives in the Hall repo at [`scripts/setup-hall-labels.sh`](../scripts/setup-hall-labels.sh).

### Usage

```bash
# All repos in the org (excluding hall-of-automata itself)
./scripts/setup-hall-labels.sh

# Specific repos only
./scripts/setup-hall-labels.sh MockaSort-Studio/my-project MockaSort-Studio/another-repo
```

Requires `gh` CLI authenticated with a token that has `write:org` or at minimum `repo` scope on the target repos.

### What it creates

| Label | Color | Purpose |
|---|---|---|
| `hall:dispatch-automaton` | blue | Standard invocation — routes to Old Major |
| `hall:old-major` | purple | Issue/PR bound to Old Major |
| `hall:hamlet` | red | Issue/PR bound to Hamlet |
| `hall:awaiting-input` | yellow | Agent waiting for invoker reply |
| `hall:queued` | orange | All invoker quota exhausted |
| `hall:invoker-queued` | orange | Invoker pool exhausted |
| `hall:active-invoker` | green | Registered active invoker |
| `hall:onboard-invoker` | light blue | Invoker onboarding in progress |
| `hall:onboard-automaton` | light blue | Automaton onboarding in progress |

`--force` updates label color and description if the label already exists.

---

## Checklist — new org or new repo

- [ ] `MockaSort-Studio/.github` repo exists with Hall templates in `.github/ISSUE_TEMPLATE/`
- [ ] `scripts/setup-hall-labels.sh` run for the target repo
- [ ] Hall GitHub App installed on the target repo (Settings → Apps → hall-of-automata → Configure)
- [ ] Webhook relay deployed and org webhook registered (see [Relay Setup](relay-setup.md))
- [ ] At least one registered invoker with quota remaining
