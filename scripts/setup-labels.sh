#!/usr/bin/env bash
# Creates all Hall system labels in a target repo.
# GitHub does not inherit labels from org level — run this once per repo.
#
# Usage:
#   ./scripts/setup-labels.sh                        # defaults to the hall repo
#   ./scripts/setup-labels.sh MockaSort-Studio/ADP8  # target repo
#
# Requires: gh (GitHub CLI), authenticated with sufficient repo access.
# Requires: yq (https://github.com/mikefarah/yq) to parse agents.yml
set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
AGENTS_YML="$(cd "$(dirname "$0")/.." && pwd)/agents.yml"

ensure_label() {
  local name="$1" color="$2" description="$3"
  if gh label list --repo "$REPO" --json name -q '.[].name' | grep -qx "$name"; then
    echo "  exists  $name"
  else
    gh label create "$name" --repo "$REPO" --color "$color" --description "$description"
    echo "  created $name"
  fi
}

echo "Setting up Hall labels in $REPO"
echo ""

echo "System labels:"
ensure_label "hall:awaiting-input" "d93f0b" "Agent is waiting for more context"
ensure_label "hall:queued"         "e4e669" "Invocation queued (cap exceeded)"

echo ""
echo "Agent labels:"
# Read agent names from agents.yml
if command -v yq &>/dev/null && [ -f "$AGENTS_YML" ]; then
  mapfile -t AGENTS < <(yq e '.agents | keys | .[]' "$AGENTS_YML")
  for agent in "${AGENTS[@]}"; do
    ensure_label "hall:$agent" "0075ca" "Bound to $agent"
  done
else
  echo "  yq not found or agents.yml missing — creating hall:hamlet manually"
  ensure_label "hall:hamlet" "0075ca" "Bound to hamlet"
fi

echo ""
echo "Done."
