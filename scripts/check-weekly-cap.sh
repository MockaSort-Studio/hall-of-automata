#!/usr/bin/env bash
# Checks the agent's weekly invocation cap against routing.yml.
# Required env: AGENT, COUNT
# Outputs: over-cap, cap
set -euo pipefail

DEFAULT=$(yq '.routing.weekly_cap' .hall/routing.yml)
OVERRIDE=$(yq ".routing.overrides.${AGENT}.weekly_cap // \"\"" .hall/routing.yml)
CAP=${OVERRIDE:-$DEFAULT}

if [ "$COUNT" -ge "$CAP" ]; then
  echo "over-cap=true"  >> "$GITHUB_OUTPUT"
else
  echo "over-cap=false" >> "$GITHUB_OUTPUT"
fi
echo "cap=$CAP" >> "$GITHUB_OUTPUT"
