#!/usr/bin/env bash
# Hall of Automata — bootstrap prerequisites check.
#
# The Hall requires no environment setup before workflows run.
# The agent catalog lives in agents.yml (repo file) and persona files
# live in roster/<slug>.md — no GitHub Environments or deployments needed.
#
# The only things that must exist before automaton onboarding can run:
#   1. A registered invoker (at least one invoker/<handle> environment with
#      CLAUDE_CODE_OAUTH_TOKEN, HALL_USAGE_COUNT, HALL_WEEKLY_CAP)
#   2. APP_ID and APP_PRIVATE_KEY as repo-level secrets (GitHub App credentials)
#
# Run this to verify your setup:
#   bash scripts/bootstrap-old-major.sh
#
# Prerequisites:
#   - gh CLI authenticated

set -euo pipefail

REPO="${GITHUB_REPOSITORY:-}"
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
fi
if [ -z "$REPO" ]; then
  echo "ERROR: could not determine repository. Run inside the repo or set GITHUB_REPOSITORY."
  exit 1
fi

echo
echo "=== Hall of Automata — bootstrap check ==="
echo "Repository: $REPO"
echo

# ── Check invoker pool ────────────────────────────────────────────────────────
echo "[1/2] Checking invoker pool..."
INVOKER_COUNT=$(gh api "/repos/$REPO/environments" --jq \
  '[.environments[] | select(.name | startswith("invoker/"))] | length' 2>/dev/null || echo "0")

if [ "$INVOKER_COUNT" -eq 0 ]; then
  echo "  WARNING: No invoker/* environments found."
  echo "  Register an invoker via the onboarding issue template before running automaton onboarding."
else
  echo "  OK: $INVOKER_COUNT invoker environment(s) registered."
fi

# ── Check repo-level secrets ─────────────────────────────────────────────────
echo "[2/2] Checking repo secrets..."
SECRETS=$(gh api "/repos/$REPO/actions/secrets" --jq '[.secrets[].name]' 2>/dev/null || echo "[]")
for SECRET in APP_ID APP_PRIVATE_KEY; do
  if echo "$SECRETS" | grep -q "\"$SECRET\""; then
    echo "  OK: $SECRET is set."
  else
    echo "  WARNING: $SECRET not found in repo secrets — workflows will fail without it."
  fi
done

echo
echo "=== Check complete ==="
echo
echo "If all checks pass, the Hall is ready. Open an onboarding issue to register"
echo "automata or invokers."
echo
