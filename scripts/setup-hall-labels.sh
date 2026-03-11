#!/usr/bin/env bash
# Creates or updates Hall labels in one or more GitHub repositories.
# Usage: ./setup-hall-labels.sh [owner/repo ...]
# With no args: applies to all repos in the org (excluding hall-of-automata).
# Requires: gh CLI authenticated with repo scope on target repos.
set -euo pipefail

ORG="${ORG:-MockaSort-Studio}"

# Format: "name|rrggbb|description"
LABELS=(
  "hall:dispatch-automaton|0075ca|Dispatch — routes to Old Major for triage"
  "hall:old-major|6e4aff|Bound to Old Major"
  "hall:hamlet|b60205|Bound to Hamlet"
  "hall:awaiting-input|e4e669|Agent waiting for invoker reply"
  "hall:queued|d93f0b|All invoker quota exhausted"
  "hall:invoker-queued|d93f0b|Invoker pool exhausted — will retry"
  "hall:active-invoker|0e8a16|Registered active invoker"
  "hall:onboard-invoker|c5def5|Invoker onboarding in progress"
  "hall:onboard-automaton|c5def5|Automaton onboarding in progress"
)

if [ "$#" -gt 0 ]; then
  REPOS=("$@")
else
  mapfile -t REPOS < <(
    gh repo list "$ORG" --limit 200 --json nameWithOwner -q '.[].nameWithOwner' \
      | grep -v "/${ORG}\.github$" \
      | grep -v "/hall-of-automata$"
  )
fi

for REPO in "${REPOS[@]}"; do
  echo "→ $REPO"
  for ENTRY in "${LABELS[@]}"; do
    IFS='|' read -r NAME COLOR DESC <<< "$ENTRY"
    if gh label create "$NAME" \
        --repo "$REPO" \
        --color "$COLOR" \
        --description "$DESC" \
        --force 2>/dev/null; then
      echo "  ✓ $NAME"
    else
      echo "  ✗ $NAME (skipped)"
    fi
  done
done

echo ""
echo "Done."
