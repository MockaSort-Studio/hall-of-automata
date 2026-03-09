#!/usr/bin/env bash
# Bootstrap the hall/roster environment.
#
# hall/roster is the only environment the Hall needs before any workflow runs.
# It holds the singleton deployment payload that Old Major writes the automaton
# catalog into at automaton-onboarding time.
#
# Old Major has no dedicated GitHub Environment:
#   - His persona is read from roster/old-major.md (repo file, not a gist)
#   - His OAuth token comes from the invoker pool (invoker/* environments),
#     selected at dispatch time by the pool-selection logic in detect/select-invoker
#
# hall/<agent> environments are created by Old Major at automaton onboarding;
# they hold PERSONA_GIST_ID as a plain variable only.
#
# invoker/<handle> environments are created by onboard-invoker.yml and hold
# CLAUDE_CODE_OAUTH_TOKEN (the dispatch pool token), HALL_USAGE_COUNT, HALL_WEEKLY_CAP.
#
# Run once (idempotent — safe to re-run):
#   bash scripts/bootstrap-old-major.sh
#
# Prerequisites:
#   - gh CLI authenticated (your normal GitHub session is enough)
#
# APP_ID and APP_PRIVATE_KEY are repo-level secrets needed by the workflows,
# not by this script. Set them once in repo Settings → Secrets after registering
# the GitHub App — this script does not touch them.
#
# What this creates:
#   hall/roster  — singleton environment for the automaton catalog deployment

set -euo pipefail

REPO="${GITHUB_REPOSITORY:-}"
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
fi
if [ -z "$REPO" ]; then
  echo "ERROR: could not determine repository. Run inside the repo or set GITHUB_REPOSITORY."
  exit 1
fi

# URL-encode an environment name (replaces / with %2F for path segments).
encode_env() { printf '%s' "${1//\//%2F}"; }

create_env() {
  local name="$1"
  local encoded
  encoded=$(encode_env "$name")
  echo "  creating environment: $name"
  gh api -X PUT "/repos/$REPO/environments/$encoded" \
    --input /dev/null \
    -H "Accept: application/vnd.github+json" \
    > /dev/null
}

seed_deployment() {
  local env_name="$1"
  local description="$2"
  echo "  seeding deployment for: $env_name"
  # GitHub requires at least one deployment for the environment page to be useful.
  # We use auto_merge=false and empty required_contexts so it creates immediately.
  gh api "/repos/$REPO/deployments" \
    -f ref=main \
    -f "environment=$env_name" \
    -f "description=$description" \
    -F auto_merge=false \
    -F "required_contexts[]=" \
    > /dev/null
}

echo
echo "=== Hall of Automata — bootstrap ==="
echo "Repository: $REPO"
echo

# ── 1. hall/roster ───────────────────────────────────────────────────────────────
echo "[1/1] hall/roster environment + seed deployment"
create_env "hall/roster"
seed_deployment "hall/roster" "Roster catalog seed — empty, written by Old Major on automaton onboarding"
echo "  done."
echo

# ── Done ─────────────────────────────────────────────────────────────────────
echo "=== Bootstrap complete ==="
echo
echo "hall/roster is ready. Old Major can now onboard automata."
echo
echo "Next: register yourself as an invoker via the onboarding issue template."
echo "The onboarding workflow uses the invoker pool for the token — at least one"
echo "invoker must be registered before automaton onboarding can run."
echo "APP_ID and APP_PRIVATE_KEY must be set as repo-level secrets separately."
