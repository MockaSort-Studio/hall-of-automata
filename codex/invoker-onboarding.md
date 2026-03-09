---
icon: material/shield-account
---

# Invoker Onboarding

An **invoker** is a contributor who has registered their Claude OAuth token with the Hall and been granted dispatch rights. Only invokers may trigger automata.

Registration validates the token with a live Claude invocation before granting access — a bad paste is caught before it causes a failed dispatch.

---

## Prerequisites

Complete both before opening the onboarding issue:

- [ ] Member of the `automata-invokers` GitHub team — ask an org admin
- [ ] `claude setup-token` completed locally — you should have received an OAuth token

---

## Process

```mermaid
flowchart TD
    A([Open New Invoker issue\nfill weekly cap in hours]) --> B[hall:onboard-invoker\nauto-applied by template]
    B --> C[[onboard-invoker — setup job]]
    C --> D[Old Major creates\ninvoker/you environment\nsets HALL_WEEKLY_CAP]
    D --> E([Old Major posts instructions\nwith environment settings link])
    E --> F([You add CLAUDE_CODE_OAUTH_TOKEN\nto invoker/you environment secrets])
    F --> G([Reply 'ready' on the issue])
    G --> H[[onboard-invoker — parse-ready job]]
    H --> I{Secret slot\nregistered?}
    I -- No --> J([Old Major prompts:\nadd secret first])
    J --> F
    I -- Yes --> K[[onboard-invoker — test-token job\nruns IN invoker/you env]]
    K --> L{Live Claude\ninvocation succeeds?}
    L -- Fail --> M([Old Major prompts:\ntoken invalid — re-run setup-token])
    M --> F
    L -- Pass --> N[[onboard-invoker — finalize job]]
    N --> O([Old Major posts\n'@you multiclassed — invoker'\nhall:active-invoker applied])
    O --> P([Issue closed\nYou can now invoke automata])
```

---

## Why the live invocation test?

Secret name presence does not validate the token value. A token that was pasted incorrectly, truncated, or has already been revoked will register as a named secret but fail at dispatch time — wasting a turn and leaving an unhelpful error. The test-token job fires a minimal one-turn Claude call inside `invoker/<you>` before access is granted. Failure produces an actionable retry prompt, not a silent broken state.

---

## Weekly cap

The cap you provide in hours is converted to **turns** (1 hour ≈ 3 turns) and stored as `HALL_WEEKLY_CAP` in your environment. The counter resets every Monday. Old Major enforces the cap during unlabeled triage; labeled dispatches have their own pre-dispatch guard.

---

## Invoking an automaton

Once registered, apply a `hall:<agent>` label to any issue or PR in a target repository. The Hall checks your team membership on every dispatch.
