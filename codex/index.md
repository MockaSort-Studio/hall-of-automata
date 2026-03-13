---
icon: material/castle
---

# Hall of Automata

![Hall](./images/favicon.png){ align=left }

---

*"A place on another plane. Constructed beings, stationed and waiting. You open the door — they come through."* [The Lorekeeper]

---

You work on multiple GitHub repos, you're ovewhealmed of work. You open an issue. A named AI agent reads it, opens a PR, survives code review, and merges — without you writing a line.

 **No server to run. No API key to manage. No external platform to pay for. GitHub is the entire backend.**

---

## What it actually is

Hall of Automata is an **AI agent orchestration layer built by overclocking GitHub itself**.

**The ingredients GitHub already provides:**

- Actions - The microservices built on top of [Claude Actions](https://github.com/anthropics/claude-code-action)
- Environments - Secret Storage
- Labels - Message bus
- Issues & PRs - The UI 
- Artifacts - The audit logs storage
- the App — The API interface. 


**What gets added on top:**

- Named agents (automata) with distinct characters, domains, and rules of engagement
- An orchestrator (Old Major) who reads incoming tasks, picks the right specialist, and dispatches
- A lifecycle that manages authorization, queueing, review loops, and cleanup

---

## Federation model

There are no API keys and no shared billing account. Instead, contributors register their personal Claude Pro/Max subscription with the Hall by storing their OAuth token in a GitHub Environment. That token stays theirs — the Hall never sees it directly; it's injected into a workflow run by GitHub's own secrets mechanism.

The pool is shared across the org. When an agent is invoked, the Hall picks the least-used contributor whose weekly cap hasn't been hit. The work runs under their quota. When it's done, their counter increments.

This makes the economics cooperative rather than extractive. If you're the only contributor, you get your own quota — same as before. If three people contribute, the org effectively gets three times the throughput for the same individual subscription cost. Every member who joins the pool multiplies capacity for everyone else. You put in one seat; you draw from the collective.

Caps reset every Monday. Contributors who hit their limit are skipped until reset; tasks queue and retry automatically overnight.

---

