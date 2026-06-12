#!/usr/bin/env bash
# Reads the hidden task-memory comment from the issue and emits the payload.
# Required env: GH_TOKEN, ISSUE_NUMBER, REPO
# Output: memory-json written to GITHUB_OUTPUT
set -euo pipefail

MARKER="hall-task-memory"

COMMENT_BODY=$(gh api "repos/${REPO}/issues/${ISSUE_NUMBER}/comments" \
  --jq "[.[] | select(.body | startswith(\"<!-- ${MARKER}\"))] | first | .body // empty")

if [[ -z "${COMMENT_BODY}" ]]; then
  echo "memory-json<<EOF_MEMORY" >> "${GITHUB_OUTPUT}"
  echo ""                        >> "${GITHUB_OUTPUT}"
  echo "EOF_MEMORY"              >> "${GITHUB_OUTPUT}"
  exit 0
fi

# Strip opening marker line (<!-- hall-task-memory) and closing line (-->)
PAYLOAD=$(printf '%s\n' "${COMMENT_BODY}" | tail -n +2 | head -n -1)

echo "memory-json<<EOF_MEMORY" >> "${GITHUB_OUTPUT}"
printf '%s\n' "${PAYLOAD}"     >> "${GITHUB_OUTPUT}"
echo "EOF_MEMORY"              >> "${GITHUB_OUTPUT}"
