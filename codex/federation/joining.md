---
icon: material/door-open
---

# Joining the Hall

Registering a new automaton in the Hall of Automata. Four steps — the first is yours, the rest require an org admin.

---

## Prerequisites

- You hold a Claude Pro or Max subscription — invocations are billed against your quota
- You have chosen a lowercase slug for your automaton (e.g. `ophelia`) and confirmed it is not in `agents.yml`
- You have drafted a persona character sheet following [`agents/automaton_template.md`](../../agents/automaton_template.md)
- An org admin is available to provision the GitHub Environment and update the roster catalog

---

## Step 1 — Generate your OAuth token (you)

On your machine:

```sh
claude setup-token
```

This opens a browser auth flow against your Claude Pro/Max account and outputs an OAuth token. Copy it — it is shown only once. Share it with your org admin along with your chosen slug.

---

## Step 2 — Org admin provisions the environment (admin)

**Create the GitHub Environment:**

1. Hall repo → Settings → Environments → New environment
2. Name: `hall/{your-slug}` (e.g. `hall/ophelia`)
3. Add secret: `CLAUDE_CODE_OAUTH_TOKEN` = (token from Step 1)
4. Add variable: `HALL_WEEKLY_CAP` = agreed quota limit (e.g. `40`)
5. Add variable: `HALL_USAGE_COUNT` = `0`
6. Set environment protection rules as appropriate

**Create the singleton deployment:**

The admin creates a GitHub Deployment on environment `hall/{your-slug}` with payload:

```json
{
  "persona_gist_id": "<id of your persona gist — see Step 3>",
  "dashboard_gist_id": "<id of your dashboard gist — see Step 3>"
}
```

This deployment is never recreated — only updated. It tracks your automaton's lifecycle state.

**Add you to the invoker team:**

Org → Teams → `automata-invokers` → Add member → your GitHub handle

Without this, the authorization check rejects your invocations.

---

## Step 3 — Set up your persona gist (you)

Create a **secret** GitHub Gist containing your character sheet (using `automaton_template.md` as the format). Copy the gist ID and share it with your admin to store in the deployment payload (Step 2).

Your persona gist is the canonical source of your automaton's identity. When updated, the change takes effect on the next invocation.

Optionally create a second gist for your automaton's **dashboard** (task history, audit log, usage stats). Share that gist ID as `dashboard_gist_id` in the deployment payload.

---

## Step 4 — Register in the catalog and repo (admin + you)

**Catalog entry** (admin updates the `hall/roster` deployment payload to include):

```json
{
  "slug": "your-slug",
  "display_name": "Your Automaton Name",
  "keeper": "your-github-handle",
  "roles": ["implement", "review"],
  "domains": ["cpp", "bazel"],
  "scope_summary": "One sentence — when to pick this agent",
  "keeper_env": "hall/your-slug"
}
```

Old Major reads this catalog at triage time to select the right agent for unlabeled invocations.

**`agents.yml` registration PR** (you open, admin merges):

```yaml
agents:
  your-slug:
    display_name: "Your Automaton Name"
    keeper_env: hall/your-slug
    keeper: your-github-handle
    teams: [automata-invokers]
    max_turns: 40
    max_retries: 3
    catalog:
      roles: [implement, review]
      domains: [cpp, bazel]
      scope_summary: "One sentence — when to pick this agent"
```

Also update `roster/README.md` and root `README.md` to add a row to the roster table.

---

## After setup

Run the label setup script in any target repos where you want direct-dispatch invocations:

```sh
./scripts/setup-labels.sh
```

Labeled invocation (`hall:your-slug`) routes directly to your automaton. Assignment-based invocation goes through Old Major first who may pick your automaton based on the catalog.

---

## Notes

- Target repos need no workflow files or secrets pre-installed. The Hall handles dispatch from its own repo.
- Your persona gist is private (secret gist) — the persona content is not public, but the gist ID is in the deployment payload which is accessible to org admins.
- Weekly cap tracking is automatic: `HALL_USAGE_COUNT` is incremented by the dispatch workflow after each successful invocation via the Environments API.
