#!/usr/bin/env bash
# Remove all hall/* GitHub Environments and their deployments.
# invoker/* environments are NOT touched.
#
# Use this to reset the Hall between smoke tests, or to clean up after
# a failed bootstrap, without destroying invoker registrations.
#
# Run:
#   bash scripts/cleanup-hall-envs.sh            # interactive confirm
#   bash scripts/cleanup-hall-envs.sh --yes       # skip confirm (CI use)
#
# Prerequisites:
#   - gh CLI authenticated with environments:write permission

set -euo pipefail

FORCE=false
for arg in "$@"; do [[ "$arg" == "--yes" ]] && FORCE=true; done

REPO="${GITHUB_REPOSITORY:-}"
if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
fi
if [ -z "$REPO" ]; then
  echo "ERROR: could not determine repository. Run inside the repo or set GITHUB_REPOSITORY."
  exit 1
fi

encode_env() { printf '%s' "${1//\//%2F}"; }

echo
echo "=== Hall of Automata — cleanup hall/* environments ==="
echo "Repository: $REPO"
echo

# Fetch all environment names matching hall/*
ENVS=$(gh api "/repos/$REPO/environments" --jq '.environments[].name' \
  | grep '^hall/' \
  | sort \
  || true)

if [ -z "$ENVS" ]; then
  echo "No hall/* environments found. Nothing to do."
  exit 0
fi

echo "Environments to delete:"
while IFS= read -r e; do echo "  - $e"; done <<< "$ENVS"
echo

if [ "$FORCE" = false ]; then
  read -r -p "Delete all of the above? This cannot be undone. [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

echo

while IFS= read -r ENV; do
  ENCODED=$(encode_env "$ENV")
  echo "Processing: $ENV"

  # Inactivate and delete all deployments first.
  # GitHub requires all deployments to be inactive before an environment can be deleted.
  DEPLOY_IDS=$(gh api "/repos/$REPO/deployments?environment=$ENCODED&per_page=100" \
    --jq '.[].id' 2>/dev/null || true)

  for DID in $DEPLOY_IDS; do
    # Mark inactive (required before deletion)
    gh api -X POST "/repos/$REPO/deployments/$DID/statuses" \
      -f state=inactive \
      -H "Accept: application/vnd.github+json" \
      > /dev/null
    # Delete deployment
    gh api -X DELETE "/repos/$REPO/deployments/$DID" \
      -H "Accept: application/vnd.github+json" \
      > /dev/null
    echo "  deleted deployment $DID"
  done

  # Delete the environment itself
  gh api -X DELETE "/repos/$REPO/environments/$ENCODED" \
    -H "Accept: application/vnd.github+json" \
    > /dev/null
  echo "  deleted environment: $ENV"
  echo
done <<< "$ENVS"

echo "=== Done. invoker/* environments were not touched. ==="
