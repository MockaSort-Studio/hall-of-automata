#!/usr/bin/env bash
# Injects re-dispatch context into CLAUDE.md.
# Required env: MODE (review | ci)
#   review mode: PR_NUMBER, REVIEW_BODY
#   ci mode:     AGENT, ATTEMPT, MAX_RETRIES, PR_NUMBER, CI_FAILURES
set -euo pipefail

case "${MODE}" in
  review)
    cat >> CLAUDE.md << 'HALLCTX'

## Hall Task Context — Review Re-dispatch

A reviewer has requested changes on the PR you opened. Address the
feedback below and push to the existing branch. Do not open a new PR.

### Review comment

HALLCTX
    printf 'PR: #%s\n\n%s\n' "$PR_NUMBER" "$REVIEW_BODY" >> CLAUDE.md
    ;;

  ci)
    cp ".hall/roster/${AGENT}.md" CLAUDE.md

    cat >> CLAUDE.md << 'HALLCTX'

## Hall Task Context — CI Re-dispatch

The CI checks below failed on the PR you previously opened.
Investigate the failures, push fixes to the same branch, and do
not open a new PR.

HALLCTX
    printf '**Attempt:** %s of %s\n**PR:** #%s\n**Failed checks:** %s\n' \
      "$ATTEMPT" "$MAX_RETRIES" "$PR_NUMBER" "$CI_FAILURES" >> CLAUDE.md
    ;;

  post-mortem)
    FAILED_RUN_URL=""
    if [ -n "${FAILED_RUN_ID:-}" ]; then
      FAILED_RUN_URL="${SERVER_URL}/${HALL_REPO}/actions/runs/${FAILED_RUN_ID}"
    fi
    cat >> CLAUDE.md << 'HALLCTX'

## Post-Mortem Context

You are running a post-mortem, not a triage dispatch. Apply your Post-Mortem Procedure.

HALLCTX
    printf -- '- Failed issue: #%s in %s/%s\n' "$ISSUE_NUMBER" "$REPO_OWNER" "$REPO_NAME" >> CLAUDE.md
    [ -n "$FAILED_RUN_URL" ] && printf -- '- Failed run: %s\n' "$FAILED_RUN_URL" >> CLAUDE.md
    printf -- '- Artifact pattern: `hall-log-*-%s-*`\n' "$ISSUE_NUMBER" >> CLAUDE.md
    printf -- '- Artifact API: `GET https://api.github.com/repos/%s/actions/artifacts?per_page=100`\n' "$HALL_REPO" >> CLAUDE.md
    printf -- '  Filter by name prefix, then fetch the download URL. Use `Authorization: Bearer ${GITHUB_TOKEN}`.\n' >> CLAUDE.md
    ;;

  *)
    echo "context-injection: unknown MODE=${MODE}" >&2
    exit 1
    ;;
esac
