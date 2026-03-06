# Secrets Model

## What lives where

| Secret | Location | Scope | Purpose |
|--------|----------|-------|---------|
| `ORG_READ_TOKEN` | Org secret | Read-only, `read:org` | Team membership checks |
| `ANTHROPIC_KEY_HAMLET` | Org secret | Anthropic API | Hamlet invocation, billed to keeper |
| *(future automaton)* | Org secret | Anthropic API | Per-automaton, billed to keeper |

Two categories. One operational secret (`ORG_READ_TOKEN`), one per-automaton secret per agent.

---

## ORG_READ_TOKEN

A GitHub Personal Access Token with `read:org` scope only. Created once, stored as an org-level secret. Used exclusively in the team membership check step.

**What it can do:** read org membership and team data.
**What it cannot do:** write anything, access repos, modify settings.

If this token leaked, an attacker could read org membership lists. That is the full blast radius.

---

## Per-automaton keys

Each automaton's Anthropic API key is stored as an org secret named `ANTHROPIC_KEY_[NAME]`. The key is provided by the automaton's keeper and billed to their Anthropic account.

The keeper owns the key. The org stores it. The workflow uses it. This is the accepted tradeoff of Option A — see [`codex/design-options.md`](../codex/design-options.md) for why this was chosen over keeping keys on keeper-owned infrastructure.

**Org admins can see these keys.** This is a known and accepted condition. Mitigation is process, not architecture: trusted admins, rotation schedule, immediate rotation on personnel change.

---

## What GitHub does not hold

- No keeper personal credentials beyond the API key
- No private keys, SSH keys, or signing credentials
- No infrastructure passwords or tokens beyond the two categories above

---

## Key masking

Every workflow that uses an API key masks it immediately to prevent accidental log exposure:

```yaml
- name: Mask key
  run: echo "::add-mask::${{ secrets.ANTHROPIC_KEY_HAMLET }}"
```

This makes the key value unsearchable in all subsequent log output, even if something attempts to print it.

---

## Rotation

Key rotation schedule and procedures are in [`codex/key-management.md`](../codex/key-management.md).
