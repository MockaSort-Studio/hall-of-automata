---
icon: material/castle
---

# Hall of Automata

> *A place on another plane. Constructed beings, stationed and waiting. You open the door — they come through.*

---

You have a GitHub repo. You open an issue. A named AI agent reads it, opens a PR, survives code review, and merges — without you writing a line.

No server to run. No API key to manage. No external platform to pay for. GitHub is the entire backend.

---

## What it actually is

Hall of Automata is an **AI agent orchestration layer built by overclocking GitHub itself**.

The ingredients GitHub already provides — Actions, Environments, Labels, Issues, PRs, the App API — turn out to be exactly sufficient for a full agent dispatch system. Workflows are the microservices. Repository environments are the secrets store. Actions Cache is task memory. Labels are the message bus. A bot identity becomes a coordinator.

No Kubernetes. No cloud functions. No message queues. The infra you already trust, doing things it wasn't designed for.

**What gets added on top:**
- Named agents (automata) with distinct characters, domains, and rules of engagement
- An orchestrator (Old Major) who reads incoming tasks, picks the right specialist, and dispatches
- A lifecycle that manages authorization, queueing, review loops, and cleanup

The result: drop a label on any issue in the org, and the right agent shows up to do the work.

---

## Federation model

There are no API keys and no shared billing account. Instead, contributors register their personal Claude Pro/Max subscription with the Hall by storing their OAuth token in a GitHub Environment. That token stays theirs — the Hall never sees it directly; it's injected into a workflow run by GitHub's own secrets mechanism.

The pool is shared across the org. When an agent is invoked, the Hall picks the least-used contributor whose weekly cap hasn't been hit. The work runs under their quota. When it's done, their counter increments.

This makes the economics cooperative rather than extractive. If you're the only contributor, you get your own quota — same as before. If three people contribute, the org effectively gets three times the throughput for the same individual subscription cost. Every member who joins the pool multiplies capacity for everyone else. You put in one seat; you draw from the collective.

Caps reset every Monday. Contributors who hit their limit are skipped until reset; tasks queue and retry automatically overnight.

---

