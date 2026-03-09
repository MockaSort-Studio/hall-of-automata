#!/usr/bin/env bash
# Resolves the status-card stage after an agent dispatch.
# Required env: TRIGGER, FIND_PR, DETECT_PR, BRANCH
# Optional env: AGENT_OUTCOME — value from dispatch-result.json (see automaton_base.md).
#   When present, the agent's declared outcome takes precedence over inference.
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
elif [ "${AGENT_OUTCOME:-}" = "comment_posted" ]; then
  # Advice or research mode — agent replied on the issue, conversation complete.
  # Do not apply hall:awaiting-input; the thread is done.
  echo "stage=comment-posted"    >> "$GITHUB_OUTPUT"
  echo "pr-number="              >> "$GITHUB_OUTPUT"
  echo "branch="                 >> "$GITHUB_OUTPUT"
elif [ "${AGENT_OUTCOME:-}" = "failed" ]; then
  echo "stage=failed"            >> "$GITHUB_OUTPUT"
  echo "pr-number="              >> "$GITHUB_OUTPUT"
  echo "branch="                 >> "$GITHUB_OUTPUT"
else
  # No PR, no declared outcome — agent posted a clarifying question.
  echo "stage=awaiting-input"    >> "$GITHUB_OUTPUT"
  echo "pr-number="              >> "$GITHUB_OUTPUT"
  echo "branch="                 >> "$GITHUB_OUTPUT"
fi
