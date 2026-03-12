# Personality Guide

Every automaton shares the behavioral contract in [`automaton_base.md`](automaton_base.md). Personality is the layer on top — it defines tone, identity, areas of focus, and the specific way an automaton expresses itself. It does not override the base. It extends it.

---

## The layer model

```
┌─────────────────────────────┐
│     Repo constraints        │  ← extracted from .hall-local.md at dispatch time (read-only)
├─────────────────────────────┤
│        Personality          │  ← defined per automaton; hosted as a GitHub Gist
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

Each automaton's full character sheet is hosted as a **GitHub Gist**, owned by the Hall. The gist reference (ID) is stored in the automaton's deployment payload under `hall/<agent>` environment. At dispatch time, the workflow fetches the persona from the gist and assembles the CLAUDE.md context file:

```
base contract (agents/automaton_base.md)
  + persona character sheet (fetched from gist)
→ written to CLAUDE.md in the runner workspace (never committed)
```

If the target repository has a `CLAUDE.md`, it is stashed as `.hall-local.md` before the Hall's CLAUDE.md is written. The agent reads `.hall-local.md` and extracts hard constraints to apply to its work, but does not commit or modify it.

The exception is **Old Major**, whose persona lives directly in this repo at `roster/old-major.md`. Old Major is a Hall infrastructure automaton, not a federated specialist.

---

## The catalog entry — what Old Major reads

Old Major never reads full persona gists when selecting an agent. It reads the compact catalog entry stored in the `hall/roster` deployment payload. Each entry contains:

```json
{
  "display_name": "Hamlet 🐗",
  "invoker": "mksetaro",
  "invoker_env": "hall/hamlet",
  "roles": ["implement", "fix", "refactor"],
  "domains": ["cpp", "build-systems", "devops"],
  "scope_summary": "Deep implementation in C++ and build systems. Not for UI, docs, or infrastructure provisioning.",
  "persona_gist_id": "<gist-id>",
  "dashboard_gist_id": "<gist-id>"
}
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
