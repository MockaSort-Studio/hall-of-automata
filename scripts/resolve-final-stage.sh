#!/usr/bin/env bash
# Resolves the status-card stage after an agent dispatch.
# Required env: TRIGGER, FIND_PR, DETECT_PR, BRANCH
# Optional env: AGENT_OUTCOME — value from dispatch-result.json (see automaton_base.md).
#   When present, the agent's declared outcome takes precedence over inference.
#   Valid values: pr_created | awaiting_input | comment_posted | rerouted | quota_exceeded | failed | max_turns_exceeded
# Optional env: MODE — dispatch mode parsed from issue body (doing | advising | researching).
#   When advising or researching and no PR was opened, output stage=done.
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
elif [ "${AGENT_OUTCOME:-}" = "quota_exceeded" ]; then
  # Claude API quota exhausted mid-dispatch. Request is queued; no PR, no question.
  # A nightly job (retry-queued.yml) will re-trigger dispatch when quota resets.
  echo "stage=queued"            >> "$GITHUB_OUTPUT"
  echo "pr-number="              >> "$GITHUB_OUTPUT"
  echo "branch="                 >> "$GITHUB_OUTPUT"
elif [ "${AGENT_OUTCOME:-}" = "max_turns_exceeded" ]; then
  # Agent hit the max_turns cap — task is incomplete but not a hard failure.
  # Treated as escalated: human review required to decide next step.
  echo "stage=escalated"         >> "$GITHUB_OUTPUT"
  echo "pr-number="              >> "$GITHUB_OUTPUT"
  echo "branch="                 >> "$GITHUB_OUTPUT"
elif [ "${AGENT_OUTCOME:-}" = "failed" ]; then
  echo "stage=failed"            >> "$GITHUB_OUTPUT"
  echo "pr-number="              >> "$GITHUB_OUTPUT"
  echo "branch="                 >> "$GITHUB_OUTPUT"
elif [ "${AGENT_OUTCOME:-}" = "comment_posted" ] || [ "${AGENT_OUTCOME:-}" = "rerouted" ]; then
  # Agent posted a substantive response (analysis, advice, blocker notice, or routing
  # decision) but no PR. Thread is done from the agent's perspective.
  echo "stage=done"              >> "$GITHUB_OUTPUT"
  echo "pr-number="              >> "$GITHUB_OUTPUT"
  echo "branch="                 >> "$GITHUB_OUTPUT"
elif [ "${MODE:-doing}" = "advising" ] || [ "${MODE:-doing}" = "researching" ]; then
  # Advising/researching mode — agent replied on the issue, conversation complete.
  # Do not apply hall:awaiting-input; the thread is done.
  echo "stage=done"              >> "$GITHUB_OUTPUT"
  echo "pr-number="              >> "$GITHUB_OUTPUT"
  echo "branch="                 >> "$GITHUB_OUTPUT"
else
  # No PR, no declared outcome — agent posted a clarifying question.
  echo "stage=awaiting-input"    >> "$GITHUB_OUTPUT"
  echo "pr-number="              >> "$GITHUB_OUTPUT"
  echo "branch="                 >> "$GITHUB_OUTPUT"
fi
