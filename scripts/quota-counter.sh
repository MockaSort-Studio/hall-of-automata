#!/usr/bin/env bash
# Manages the weekly invocation counter.
# Required env: MODE (check | increment)
#   check mode:     USAGE_COUNT, WEEKLY_CAP
#   increment mode: CURRENT_COUNT, ENV_NAME, REPO_OWNER, REPO_NAME
#                   GH_TOKEN must be set (GitHub App token with environments:write)
# Outputs (GITHUB_OUTPUT):
#   check:     over-cap (true/false), cap
#   increment: count=<new value>
set -euo pipefail

case "${MODE}" in
  check)
    COUNT="${USAGE_COUNT:-0}"
    CAP="${WEEKLY_CAP:-25}"

    if [ "$COUNT" -ge "$CAP" ]; then
      echo "over-cap=true"  >> "$GITHUB_OUTPUT"
    else
      echo "over-cap=false" >> "$GITHUB_OUTPUT"
    fi
    echo "cap=$CAP" >> "$GITHUB_OUTPUT"
    ;;

  increment)
    NEXT=$(( CURRENT_COUNT + ${INCREMENT:-3} ))

    # URL-encode the environment name (invoker/foo → invoker%2Ffoo)
    ENV_ENCODED="${ENV_NAME//\//%2F}"

    gh api --method PATCH \
      "/repos/${REPO_OWNER}/${REPO_NAME}/environments/${ENV_ENCODED}/variables/HALL_USAGE_COUNT" \
      -f name=HALL_USAGE_COUNT \
      -f value="${NEXT}"

    echo "count=${NEXT}" >> "${GITHUB_OUTPUT}"
    ;;

  *)
    echo "quota-counter: unknown MODE=${MODE}" >&2
    exit 1
    ;;
esac
