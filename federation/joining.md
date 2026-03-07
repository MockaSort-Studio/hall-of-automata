# Joining the Hall

Registering a new agent in the Hall of Automata. Follow these steps in order.

---

## Prerequisites

- You are a member of the MockaSort Studio org
- You hold a Claude Pro or Max subscription (the OAuth token is tied to your subscription quota)
- You have chosen a name for your agent — a lowercase slug (`hamlet`, `ophelia`) — and confirmed it is not already in `agents.yml`
- An org admin is available to create the GitHub Environment and add you to the invoker team

---

## Step 1 — Generate your OAuth token

On your machine, run:

```sh
claude setup-token
```

This opens a browser flow, authenticates with your Claude Pro/Max account, and outputs an OAuth token. Copy it — it is only shown once.

This token is billed against your own Claude subscription quota. There is no Anthropic API key involved.

---

## Step 2 — Create the GitHub Environment

An org admin creates a GitHub Environment in the Hall repo:

1. Hall repo → Settings → Environments → New environment
2. **Name:** `hall/{your-agent-name}` (e.g. `hall/ophelia`)
3. Add secret: `CLAUDE_CODE_OAUTH_TOKEN` = (paste your token from Step 1)
4. Set protection rules if desired (e.g. require approval for the environment)

The token is now under your agent's isolated environment. No other agent's job can access it.

---

## Step 3 — Register the agent in `agents.yml`

Open a PR to the Hall repo adding your agent to `agents.yml`:

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

Optionally add a `routing.yml` override if your agent needs a different weekly cap.

---

## Step 4 — Write the roster profile

Create `roster/{your-agent}.md` in the Hall repo. Use [`roster/hamlet.md`](../roster/hamlet.md) as a template. Include:

- Identity and personality summary (this becomes the agent's `CLAUDE.md` at dispatch time)
- Keeper and contact details
- Capabilities
- Behavioral notes specific to this agent

The persona file is the agent's sole behavioral contract — everything the agent knows about how to behave comes from this file at dispatch time.

---

## Step 5 — Create labels in target repos

Each target repo where the agent can be invoked needs:

- `hall:{your-agent}` — applied by the Hall to bind the agent to a PR

The Hall creates `hall:{agent}` automatically on first dispatch if it does not exist. No manual label creation is required.

---

## Step 6 — Add keeper to the invoker team

An org admin adds your GitHub handle to the team listed in `agents.yml` (`automata-invokers` by default). This grants invocation rights — without team membership, the authorization step rejects all invocations.

---

## Step 7 — Update the roster table

Add a row to [`roster/README.md`](../roster/README.md) and the root [`README.md`](../README.md). Include this in the same PR as Steps 3 and 4.

---

## Done

Once the PR is merged and the Environment is live, the agent is federated. Anyone in the authorized team can comment `@hall-of-automata[bot] {your-agent}` on any issue or apply a matching label — and the Hall will dispatch your agent.

---

## No per-repo configuration required

Target repositories do not need any workflow files, secrets, or labels pre-created. The Hall repo's `invoke.yml` triggers on events from the Hall repo itself (for MVP), with org-wide coverage coming via the webhook relay (see `TODO.md` Deferred section). The Hall app installation token handles all cross-repo API access.
