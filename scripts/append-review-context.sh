#!/usr/bin/env bash
# Appends review re-dispatch context to CLAUDE.md.
# Required env: PR_NUMBER, REVIEW_BODY
set -euo pipefail

cat >> CLAUDE.md << 'HALLCTX'

## Hall Task Context — Review Re-dispatch

A reviewer has requested changes on the PR you opened. Address the
feedback below and push to the existing branch. Do not open a new PR.

### Review comment

HALLCTX
printf 'PR: #%s\n\n%s\n' "$PR_NUMBER" "$REVIEW_BODY" >> CLAUDE.md
