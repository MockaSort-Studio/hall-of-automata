# Security

The threat model, hardening measures, and ongoing obligations for the Hall of Automata.

---

## Threat model

The system's security rests on two assumptions:

1. **Org admins are trusted.** They have access to org secrets. If an admin is hostile, the key custody model collapses. This is an organizational assumption, not a technical one.
2. **Workflow source is protected.** A malicious modification to `.github/workflows/` could bypass the team membership check or exfiltrate secrets. Protection is enforced via branch rules and CODEOWNERS.

Threats outside this model — compromised GitHub infrastructure, Anthropic-side breaches — are not in scope here.

---

## Protecting workflow source

The most important protection in the system. A workflow that can be modified by anyone can do anything, including printing secrets to logs.

**Branch protection on `main`:**
- Require pull request reviews before merging
- Require at least 1 approval from a code owner
- Dismiss stale reviews when new commits are pushed
- Do not allow bypass by admins (ideally)

**CODEOWNERS:**

```
# .github/CODEOWNERS
.github/workflows/  @MockaSort-Studio/admins
```

Any change to workflow files requires approval from the `admins` team. This is the primary guard against workflow tampering.

---

## Secret hygiene

**Key masking in every workflow:**

```yaml
- name: Mask key
  run: echo "::add-mask::${{ secrets.ANTHROPIC_KEY_HAMLET }}"
```

This must be the first step after authorization passes, before any step that uses the key. Once masked, the value is redacted from all subsequent log output.

**Never print secrets explicitly.** No `echo $SECRET`, no debug steps that dump environment variables. If `ACTIONS_STEP_DEBUG` is ever enabled (it reveals more log detail), disable it in production.

**Minimal workflow permissions:**

```yaml
permissions:
  issues: write    # post result comments
  contents: read   # checkout if needed
```

Nothing else. The `GITHUB_TOKEN` should not have write access to anything it does not need.

---

## Fail-closed authorization

The team membership check returns `false` on any error — API failure, user not found, token issue. The invocation does not proceed on ambiguity.

```javascript
try {
  const res = await github.rest.teams.getMembershipForUserInOrg({ ... });
  return res.data.state === 'active';
} catch {
  return false;  // fail closed
}
```

An attacker cannot bypass the check by triggering an API error.

---

## Concurrency

Concurrent invocations of the same automaton on the same issue are serialized, not raced:

```yaml
concurrency:
  group: hamlet-${{ github.event.issue.number }}
  cancel-in-progress: false
```

`cancel-in-progress: false` queues rather than cancels. Both invocations run, in order. If cancellation is preferred (last writer wins), set to `true`.

---

## Invocation timeout

All workflows set a hard timeout:

```yaml
timeout-minutes: 30
```

A stuck or runaway invocation does not run indefinitely. Adjust per automaton if tasks are expected to take longer, but always set an explicit limit.

---

## Audit trail

Every invocation leaves two records:
- **Actions log:** timestamp, trigger, sender, job result
- **Issue comment:** automaton response or unauthorized notice

These are not deletable by regular org members. They provide a complete history of who invoked what and when.

---

## What this does not protect against

- A compromised keeper account with direct org admin rights
- GitHub infrastructure compromise
- Anthropic-side data handling (governed by Anthropic's terms)
- Issues in repos where the workflow is not present (invocation silently does nothing — the label has no workflow to trigger)
