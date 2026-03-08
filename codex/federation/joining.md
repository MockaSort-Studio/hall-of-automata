# Joining the Hall

Registering a new agent in the Hall of Automata. Three steps — two involve an org admin.

---

## Prerequisites

- You hold a Claude Pro or Max subscription (OAuth token is billed against your quota)
- You have chosen a lowercase slug for your agent (`hamlet`, `ophelia`) and confirmed it is not in `agents.yml`
- An org admin is available to create the GitHub Environment and add you to the invoker team

---

## Step 1 — Generate your OAuth token (you)

On your machine:

```sh
claude setup-token
```

This opens a browser flow, authenticates with your Claude Pro/Max account, and outputs an OAuth token. Copy it — it is shown only once. Send it to your org admin along with your chosen agent name.

---

## Step 2 — Org admin setup (admin)

The admin does both of these:

**Create the GitHub Environment:**

1. Hall repo → Settings → Environments → New environment
2. Name: `hall/{your-agent-name}` (e.g. `hall/ophelia`)
3. Add secret: `CLAUDE_CODE_OAUTH_TOKEN` = (token from Step 1)
4. Set environment protection rules if desired

**Add you to the invoker team:**

- Org → Teams → `automata-invokers` → Add member → your GitHub handle

Without team membership, the authorization step rejects all invocations.

---

## Step 3 — Registration PR (you)

Open a PR to the Hall repo with three changes:

**`agents.yml`** — add your agent entry:

```yaml
agents:
  your-agent:
    environment: hall/your-agent
    secret: CLAUDE_CODE_OAUTH_TOKEN
    persona: roster/your-agent.md
    teams: [automata-invokers]   # or a more restricted team
    max_turns: 40
    max_retries: 3
    capabilities: [implement, review, fix, refactor]
    keeper: your-github-handle
```

Optionally add a `routing.yml` override for a custom weekly cap.

**`roster/{your-agent}.md`** — write the persona file. Use [`roster/hamlet.md`](../roster/hamlet.md) as a template. This file is the agent's sole behavioral contract — it becomes the agent's `CLAUDE.md` at dispatch time.

**`roster/README.md` and root `README.md`** — add a row to each roster table.

---

## After the PR merges

Run the label setup script once in the Hall repo (and any target repos where you want to invoke this agent):

```sh
./scripts/setup-labels.sh
```

Anyone in the authorized team can now invoke your agent by applying `hall:{your-agent}` to an issue, or by commenting `@hall-of-automata[bot] {your-agent}`.

---

## Notes

- Target repos need no workflow files, secrets, or labels pre-created. The Hall creates `hall:{agent}` automatically on first dispatch if it does not exist.
- System labels (`hall:awaiting-input`, `hall:queued`) are created by `setup-labels.sh`. GitHub does not sync org-level labels to repos automatically.
- The Hall currently only reacts to events on the Hall repo itself. Org-wide coverage requires the webhook relay (see `TODO.md`).
