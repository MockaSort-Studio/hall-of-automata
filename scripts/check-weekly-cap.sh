#!/usr/bin/env bash
# Checks the agent's weekly invocation cap.
# Required env: USAGE_COUNT, WEEKLY_CAP
# Cap and count are read from GitHub Environment variables in the calling job
# (vars.HALL_USAGE_COUNT and vars.HALL_WEEKLY_CAP) — no routing.yml, no yq.
# Outputs: over-cap, cap
set -euo pipefail

COUNT="${USAGE_COUNT:-0}"
CAP="${WEEKLY_CAP:-25}"

if [ "$COUNT" -ge "$CAP" ]; then
  echo "over-cap=true"  >> "$GITHUB_OUTPUT"
else
  echo "over-cap=false" >> "$GITHUB_OUTPUT"
fi
echo "cap=$CAP" >> "$GITHUB_OUTPUT"
