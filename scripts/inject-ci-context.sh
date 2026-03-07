#!/usr/bin/env bash
# Copies the agent persona to CLAUDE.md and appends CI re-dispatch context.
# Required env: AGENT, ATTEMPT, MAX_RETRIES, PR_NUMBER, CI_FAILURES
set -euo pipefail

cp ".hall/roster/${AGENT}.md" CLAUDE.md

cat >> CLAUDE.md << 'HALLCTX'

## Hall Task Context — CI Re-dispatch

The CI checks below failed on the PR you previously opened.
Investigate the failures, push fixes to the same branch, and do
not open a new PR.

HALLCTX
printf '**Attempt:** %s of %s\n**PR:** #%s\n**Failed checks:** %s\n' \
  "$ATTEMPT" "$MAX_RETRIES" "$PR_NUMBER" "$CI_FAILURES" >> CLAUDE.md
