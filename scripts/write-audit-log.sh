#!/usr/bin/env bash
# Writes the invocation audit log to hall-invocation-log.json.
# Required env: AGENT, AGENT_DISPATCHED, REROUTED, REPO_OWNER, REPO_NAME,
#               ISSUE_NUMBER, PR_NUMBER, INVOKER, TEAM_VALIDATED,
#               TIMESTAMP_START, TURNS_USED, TURNS_MAX, RETRY_COUNT,
#               OUTCOME, WEEKLY_COUNT_AFTER
set -euo pipefail

PR_VALUE="${PR_NUMBER:-null}"
[[ -n "${PR_NUMBER:-}" ]] && PR_VALUE="${PR_NUMBER}" || PR_VALUE="null"

cat > hall-invocation-log.json << EOF
{
  "agent_requested":    "${AGENT}",
  "agent_dispatched":   "${AGENT_DISPATCHED}",
  "rerouted":           ${REROUTED},
  "repo":               "${REPO_OWNER}/${REPO_NAME}",
  "issue":              ${ISSUE_NUMBER},
  "pr":                 ${PR_VALUE},
  "invoker":            "${INVOKER}",
  "team_validated":     "${TEAM_VALIDATED}",
  "timestamp_start":    "${TIMESTAMP_START}",
  "timestamp_end":      "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "turns_used":         ${TURNS_USED},
  "turns_max":          ${TURNS_MAX},
  "retry_count":        ${RETRY_COUNT},
  "outcome":            "${OUTCOME}",
  "weekly_count_after": ${WEEKLY_COUNT_AFTER}
}
EOF
