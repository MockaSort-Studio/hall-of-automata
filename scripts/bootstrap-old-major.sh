#!/usr/bin/env bash
# Bootstrap Old Major and the hall/roster environment.
#
# Old Major is Hall-native: his persona lives in roster/old-major.md (repo file).
# No gist or deployment payload is needed — he is a special case, not a
# federated automaton. This script only needs to create the two environments
# that invoke.yml and onboard-automaton.yml require to function.
#
# Run once (idempotent — safe to re-run if partially complete):
#   bash scripts/bootstrap-old-major.sh
#
# Prerequisites:
#   - gh CLI authenticated with a token that has environments:write permission
#   - GitHub App registered; APP_ID and APP_PRIVATE_KEY set as repo secrets
#   - Your CLAUDE_CODE_OAUTH_TOKEN ready (from `claude setup-token`)
#
# What this creates:
#   hall/old-major   — Old Major's environment (secret slot only, no usage vars)
#   hall/roster      — singleton environment for the automaton catalog deployment

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
    -f auto_merge=false \
    -F "required_contexts[]=" \
    > /dev/null
}

echo
echo "=== Hall of Automata — Old Major bootstrap ==="
echo "Repository: $REPO"
echo

# ── 1. hall/old-major ─────────────────────────────────────────────────────────
echo "[1/2] hall/old-major environment"
create_env "hall/old-major"
echo "  done."
echo

# ── 2. hall/roster ───────────────────────────────────────────────────────────
echo "[2/2] hall/roster environment + seed deployment"
create_env "hall/roster"
seed_deployment "hall/roster" "Roster catalog seed — empty, updated by Old Major on automaton onboarding"
echo "  done."
echo

# ── Done ─────────────────────────────────────────────────────────────────────
ENV_URL="https://github.com/$REPO/settings/environments"
echo "=== Bootstrap complete ==="
echo
echo "One manual step required:"
echo "  1. Open ${ENV_URL}"
echo "  2. Select 'hall/old-major'"
echo "  3. Add secret: CLAUDE_CODE_OAUTH_TOKEN"
echo "     (value from: claude setup-token)"
echo
echo "Old Major's persona is loaded from roster/old-major.md at dispatch time."
echo "No gist or deployment payload is needed for him."
echo
echo "After adding the secret, automaton onboarding (hall:onboard-automaton)"
echo "will work. Invoker onboarding requires NO hall/* environment — run it now."
