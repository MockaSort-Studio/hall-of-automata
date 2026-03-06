# Joining the Hall

Registering an automaton in the Hall of Automata. Follow these steps in order.

---

## Prerequisites

- You are a member of MockaSort Studio org
- You have an Anthropic account with API access
- You have chosen a name for your automaton and confirmed it is not already in the roster
- An org admin is available to add secrets and manage team membership (or you have org admin rights)

---

## Step 1 — Generate an API key

In your Anthropic account, create a new API key scoped to this automaton. Do not reuse a key you use for other purposes — this key will live in org secrets and should be isolatable.

Keep the key value ready for Step 2. You will not need it again after it is stored.

---

## Step 2 — Store the key as an org secret

An org admin adds the key to MockaSort Studio org secrets:

- **Name:** `ANTHROPIC_KEY_[AUTOMATON_NAME]` (uppercase, e.g. `ANTHROPIC_KEY_HAMLET`)
- **Value:** the key from Step 1
- **Access:** all repositories (the automaton can be invoked from any org repo)

The key is now under org custody. See [`architecture/secrets-model.md`](../architecture/secrets-model.md) for what this implies.

---

## Step 3 — Create the invocation label

The label must exist in every repo where the automaton can be invoked. For org-wide availability, create it in each repo or use the GitHub API to add it across repos.

**Label name:** lowercase automaton name (e.g. `hamlet`)
**Color:** keeper's choice — pick something distinct from existing labels

---

## Step 4 — Add the workflow file to each target repo

The invocation workflow must exist in every repo where the automaton can be invoked. The base logic lives centrally in `hall-of-automata` — each repo only needs a thin wrapper that calls it.

Copy [`invoke-hamlet.yml`](../.github/workflows/invoke-hamlet.yml) into `.github/workflows/` of the target repo. Adapt:
- Job names and trigger label (`github.event.label.name == 'your-name'`)
- `automaton-name`, `label-name` inputs
- `ANTHROPIC_API_KEY` secret reference (`secrets.ANTHROPIC_KEY_[NAME]`)
- `personality-instructions` input — personality layer for this automaton

The wrapper calls `MockaSort-Studio/hall-of-automata/.github/workflows/_base-invoke.yml@main` for all shared logic: auth check, label removal, CLAUDE.md override, and Claude Code Action invocation.

**Note on CLAUDE.md:** the workflow intentionally deletes any local `CLAUDE.md` in the target repo before invoking the agent and replaces it with the Hall's behavior contract. Do not rely on local `CLAUDE.md` files to control automaton behavior. See [`agents/base-behavior.md`](../agents/base-behavior.md).

**Triggers covered by the wrapper:**
- Issue labeled with the automaton's label → initial invocation
- Issue comment containing `@[name]` → follow-up or re-invocation
- PR review submitted on a PR carrying the automaton's label → feedback loop

---

## Step 5 — Add keeper to automata-invokers

An org admin adds the keeper to the `automata-invokers` team if they are not already a member. This grants the keeper invocation rights for all automata in the Hall, including their own.

---

## Step 6 — Write the roster profile

Create `roster/[name].md` in this repo. Use [`roster/hamlet.md`](../roster/hamlet.md) as a template. Include:

- Identity and personality summary
- Keeper details and API key secret name
- Invocation label and team
- Capabilities
- Contact

Open a PR to this repo. An existing Hall member reviews and merges.

---

## Step 7 — Update the roster table

Add a row to the table in [`roster/README.md`](../roster/README.md) and in the root [`README.md`](../README.md).

Include this in the same PR as Step 6.

---

## Done

Once the PR is merged, the automaton is federated. Anyone in `automata-invokers` can apply the label and the automaton will respond.
