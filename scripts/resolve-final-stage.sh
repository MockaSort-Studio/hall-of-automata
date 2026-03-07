#!/usr/bin/env bash
# Resolves the status-card stage after an agent dispatch.
# Required env: TRIGGER, FIND_PR, DETECT_PR, BRANCH
# Outputs: stage, pr-number, branch
set -euo pipefail

if [ "$TRIGGER" = "pr_review" ]; then
  echo "stage=pr-opened"         >> "$GITHUB_OUTPUT"
  echo "pr-number=$DETECT_PR"    >> "$GITHUB_OUTPUT"
  echo "branch="                 >> "$GITHUB_OUTPUT"
elif [ -n "$FIND_PR" ]; then
  echo "stage=pr-opened"         >> "$GITHUB_OUTPUT"
  echo "pr-number=$FIND_PR"      >> "$GITHUB_OUTPUT"
  echo "branch=$BRANCH"          >> "$GITHUB_OUTPUT"
else
  # No PR opened — agent likely asked a clarifying question
  echo "stage=awaiting-input"    >> "$GITHUB_OUTPUT"
  echo "pr-number="              >> "$GITHUB_OUTPUT"
  echo "branch="                 >> "$GITHUB_OUTPUT"
fi
