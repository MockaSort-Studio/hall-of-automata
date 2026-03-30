---
icon: material/key
---

# Generating Your Claude OAuth Token

Hall of Automata agents run under your Claude Pro or Max account. You donate quota by registering as an invoker — this requires a Claude OAuth token that the Hall stores in a GitHub Environment and uses exclusively for agent dispatches on your behalf.

---

## Step 1 — Install Claude Code CLI

=== "macOS / Linux"

    ```bash
    npm install -g @anthropic-ai/claude-code
    ```

=== "Windows"

    ```powershell
    npm install -g @anthropic-ai/claude-code
    ```

Requires Node.js 18 or later. Verify with `node --version`.

---

## Step 2 — Authenticate

Run Claude Code and complete the browser OAuth flow:

```bash
claude
```

A browser window will open asking you to sign in with your Anthropic account. Complete the flow, then return to the terminal.

---

## Step 3 — Copy your token

=== "macOS / Linux"

    ```bash
    cat ~/.claude/.credentials.json
    ```

=== "Windows"

    Open `%APPDATA%\Claude\.credentials.json` in any text editor.

The file contains a JSON object. Copy the value of the `oauthToken` field — it starts with `sk-ant-oat`.

---

## Step 4 — Register as an invoker

Return to the Hall's getting-started issue in your org's `hall-of-automata` repo and apply the `hall:onboard-invoker` label. The onboarding workflow will prompt you to paste your token as a GitHub Actions secret.

---

!!! warning "Treat this token as a password"
    Your OAuth token grants full Claude Pro/Max usage on your behalf. Anyone who holds it can consume your quota. Do not share it, do not commit it to any repository, and do not paste it anywhere other than the invoker registration flow.

    If you believe your token has been compromised, regenerate it by running `claude` again and completing a fresh OAuth flow. Then re-register as an invoker with the new token.
