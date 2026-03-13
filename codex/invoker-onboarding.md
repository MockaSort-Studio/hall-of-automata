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
- [ ] [Open issue](https://github.com/MockaSort-Studio/hall-of-automata/issues/new/choose)

---

## Process

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '15px', 'primaryColor': '#1e3a5f', 'primaryTextColor': '#e2e8f0', 'primaryBorderColor': '#3b82f6', 'lineColor': '#60a5fa', 'secondaryColor': '#1e293b', 'tertiaryColor': '#0f1929', 'clusterBkg': '#0d1b2e', 'clusterBorder': '#334155', 'titleColor': '#c0cfe4', 'edgeLabelBackground': '#0f1929'}}}%%

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

    classDef user fill:#0f766e,stroke:#14b8a6,color:#ccfbf1,stroke-width:2px
    classDef system fill:#1e3a8a,stroke:#3b82f6,color:#dbeafe,stroke-width:2px
    classDef agent fill:#4c1d95,stroke:#7c3aed,color:#ede9fe,stroke-width:2px
    classDef decision fill:#78350f,stroke:#f59e0b,color:#fef3c7,stroke-width:2px
    classDef success fill:#14532d,stroke:#22c55e,color:#dcfce7,stroke-width:2px

    class A,F,G user
    class B,C,H,K,N system
    class D,E,J,M,O agent
    class I,L decision
    class P success
```

---

## Weekly cap

The cap you provide in hours is converted to **turns** (1 hour ≈ 3 turns) and stored as `HALL_WEEKLY_CAP` in your environment. The counter resets every Monday. Old Major enforces the cap during unlabeled triage; labeled dispatches have their own pre-dispatch guard.
