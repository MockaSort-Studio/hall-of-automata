#!/usr/bin/env bash
# Increments HALL_USAGE_COUNT for an invoker environment via the GitHub REST API.
# Required env: CURRENT_COUNT, ENV_NAME (e.g. invoker/<githandle>), REPO_OWNER, REPO_NAME
# GH_TOKEN must be set (GitHub App token with environments:write).
# Output (GITHUB_OUTPUT): count=<new value>
set -euo pipefail

NEXT=$(( CURRENT_COUNT + 1 ))

# URL-encode the environment name (invoker/foo → invoker%2Ffoo)
ENV_ENCODED="${ENV_NAME//\//%2F}"

gh api --method PATCH \
  "/repos/${REPO_OWNER}/${REPO_NAME}/environments/${ENV_ENCODED}/variables/HALL_USAGE_COUNT" \
  -f name=HALL_USAGE_COUNT \
  -f value="${NEXT}"

echo "count=${NEXT}" >> "${GITHUB_OUTPUT}"
