---
icon: material/handshake
---

# Joining the Federation

This page covers what happens in your repository when the Hall is granted access to it — what gets written, what attribution is applied, and what the agent is never permitted to do. No surprises.

---

## The `.hall-local.md` file

!!! question "A file will be committed to your repository"
    When an automaton works in your repository for the first time, it creates and commits **`.hall-local.md`** at the repo root.

    This file is the Hall's persistent memory for that repository — a compact architectural map the agent writes so that future invocations can orient themselves immediately without re-reading the whole codebase. It contains:

    | Sigil | Contents |
    |-------|----------|
    | `!arch` | Key files and their roles |
    | `!con` | Hard constraints distilled from your project rules |
    | `!dec` | Significant approach decisions made during a task |
    | `!log` | Dispatch log — one entry per invocation |

    **It holds no secrets, no credentials, and no personal data.** It is plain text, committed under the same co-authored-by attribution as all other Hall work, and fully auditable in your repository history. If you prefer not to keep it, delete it at any time — the agent will rebuild it on the next invocation.

---

## What the agent commits

Every commit an automaton makes carries an explicit attribution trailer:

```
Co-authored-by: <Automaton Name> <hall-of-automata[bot]@users.noreply.github.com>
```

This appears in your git log and in GitHub's UI. You always know which changes came from the Hall and which automaton made them.

Work happens on a branch named `hall/<agent>/issue-<N>`. The agent opens a pull request; **a human merges it**. The Hall never force-pushes, never pushes directly to main, and never merges its own PRs.

---

## What the agent never does

These are hard stops in the base contract — no persona can override them:

- **Never commits `CLAUDE.md`** or any other `.hall-*` prefixed file (`.hall-local.md` is the sole exception).
- **Never touches files containing secrets or credentials.**
- **Never takes destructive or irreversible actions** (branch deletion, table drops, CI job removal) without explicit sign-off in the issue.
- **Never modifies core architecture** without explicit sign-off.
- **Never pushes directly to a protected branch.**

If the agent cannot proceed without crossing one of these lines, it posts a comment explaining what is missing and halts.

---

## What your `CLAUDE.md` is used for

If your repository has a `CLAUDE.md`, the Hall reads it **once** on first dispatch to extract hard constraints — things like "never modify `src/generated/`" or "always run `make lint` before committing". These are distilled into `!con` entries in `.hall-local.md` and applied on every subsequent invocation.

Your `CLAUDE.md` is never renamed, overwritten, committed, or removed. The Hall leaves it exactly as it found it.

---

## Opting out

There is no formal opt-in required from the receiving repository. The GitHub App installation and the invoker's authorisation on the source repo are the control gates. If you want to constrain what the Hall can do in your repo:

- Add rules to your `CLAUDE.md` — they will be picked up as `!con` constraints.
- Rely on branch protection to enforce human review before any Hall PR merges.
- Revoke the App installation from your org's GitHub settings at any time.
