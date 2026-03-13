# Personality Guide

Every automaton shares the behavioral contract in [`automaton_base.md`](automaton_base.md). Personality is the layer on top — it defines tone, identity, areas of focus, and the specific way an automaton expresses itself. It does not override the base. It extends it.

---

## The layer model

```
┌─────────────────────────────┐
│     Repo context            │  ← .hall-local.md: read at start, updated and committed at end
├─────────────────────────────┤
│        Personality          │  ← defined per automaton in roster/<slug>.md
├─────────────────────────────┤
│       Base Contract         │  ← shared, in this repo: agents/automaton_base.md
├─────────────────────────────┤
│      Claude (Anthropic)     │  ← underlying model capabilities
└─────────────────────────────┘
```

The base contract sets the rules. Personality sets the character. Repo constraints apply the local context. The model does the work.

---

## Persona format — the character sheet

Each automaton's persona follows a fixed three-section structure defined in [`automaton_template.md`](automaton_template.md). The structure is deliberately sparse:

**Character** — identity, tone adjectives, voice register, automaton-specific behavioral rules, signature format. This is the D&D character sheet: dense, non-redundant, immediately parseable by the model.

**Domains** — named capability bundles, not tool lists. `cpp` implies a toolset. `devops` implies another. Naming the domain is enough; enumerating individual tools adds noise that drifts out of sync. Each domain line is one sentence stating what the territory covers and implies.

**Scope** — explicit right-call / not-right-call boundaries, plus an automaton-specific ambiguity gate defining when it stops and asks rather than proceeding. This is what Old Major reads when routing.

---

## What belongs in personality

- **Name and identity** — who the automaton is, their lore, their disposition
- **Tone modifiers** — more terse, more sardonic, more formal, more direct than the base default
- **Automaton-specific rules** — constraints that go beyond the base, not duplicates of it
- **Signature style** — exact format, used consistently
- **Scope boundaries** — what task types are right and wrong fits

## What does not belong in personality

- Overrides to base contract rules — those are non-negotiable
- Authorization logic — that lives in the workflow
- Tool enumeration — domains imply tools; listing them is noise

---

## Where personas live

Each automaton's character sheet lives in the Hall repo at `roster/<slug>.md`. At dispatch time, the workflow assembles the CLAUDE.md context file in the runner workspace:

```
base contract (agents/automaton_base.md)
  + persona character sheet (roster/<slug>.md)
→ written to CLAUDE.md in the runner workspace (never committed)
```

The target repository's `CLAUDE.md` is never renamed or copied into `.hall-local.md`. On first dispatch to a repo, the step stashes it as `.hall-original-claude.md` (ephemeral, never committed) so the agent can read it once and distil its constraints into `.hall-local.md`. `.hall-local.md` is a Hall-native compact memory file — architectural map, constraints, dispatch log — maintained and committed by the agent at every invocation. See the `.hall-local.md` contract in `automaton_base.md`.

All persona files live in this repo. Old Major is not a special case — his persona is at `roster/old-major.md`, same as every other automaton.

---

## The catalog entry — what Old Major reads

Old Major reads the compact catalog from `agents.yml` when routing. Each entry contains:

```yaml
slug: hamlet
display_name: "Hamlet 🐗"
author: mksetaro
catalog:
  domains: [cpp, build-systems, debugging]
  scope_summary: "Deep implementation in C++ and build systems. Not for UI, docs, or non-C++ work."
max_turns: 40
```

The catalog entry and the full persona character sheet must stay in sync. When a persona is updated, the catalog entry's `scope_summary` must be reviewed.

---

## Example: Hamlet

Hamlet's personality additions over the base contract:

- Brutalist MockaSort tone — more pronounced than the base default
- Dry humor explicitly permitted (base says it "earns its place"; Hamlet uses it more freely)
- Signs work with `// Hamlet 🐗 — [something specific to this invocation]`
- Peer-level relationship — no servile language, no "as requested"
- Will say if something is wrong, once, then proceed

None of this contradicts the base. It sharpens it.
