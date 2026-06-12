#!/usr/bin/env bash
# Upserts a hidden task-memory comment on the issue.
# Required env: GH_TOKEN, ISSUE_NUMBER, REPO, MEMORY_JSON
set -euo pipefail

MARKER="hall-task-memory"
COMMENT_BODY="<!-- ${MARKER}
${MEMORY_JSON}
-->"

EXISTING_ID=$(gh api "repos/${REPO}/issues/${ISSUE_NUMBER}/comments" \
  --jq "[.[] | select(.body | startswith(\"<!-- ${MARKER}\"))] | first | .id // empty")

if [[ -n "${EXISTING_ID}" ]]; then
  gh api "repos/${REPO}/issues/comments/${EXISTING_ID}" \
    --method PATCH \
    --field body="${COMMENT_BODY}" \
    --silent
else
  gh api "repos/${REPO}/issues/${ISSUE_NUMBER}/comments" \
    --method POST \
    --field body="${COMMENT_BODY}" \
    --silent
fi
