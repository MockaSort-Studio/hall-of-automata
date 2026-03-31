#!/usr/bin/env bash
# Writes the invocation audit log to hall-invocation-log.json.
# Required env: AGENT, AGENT_DISPATCHED, REROUTED, REPO_OWNER, REPO_NAME,
#               ISSUE_NUMBER, PR_NUMBER, INVOKER, TEAM_VALIDATED,
#               TIMESTAMP_START, TURNS_USED, TURNS_MAX, RETRY_COUNT,
#               OUTCOME, WEEKLY_COUNT_AFTER
# Optional env: MODEL, MCP_SERVERS (comma-separated)
set -euo pipefail

PR_VALUE="${PR_NUMBER:-null}"
[[ -n "${PR_NUMBER:-}" ]] && PR_VALUE="${PR_NUMBER}" || PR_VALUE="null"

TIMESTAMP_END="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Duration in seconds (start → end)
DURATION_SECONDS="null"
if [[ -n "${TIMESTAMP_START:-}" ]]; then
  start_epoch=$(date -d "${TIMESTAMP_START}" +%s 2>/dev/null || echo "0")
  end_epoch=$(date -u +%s)
  if [[ "$start_epoch" -gt 0 ]]; then
    DURATION_SECONDS=$(( end_epoch - start_epoch ))
  fi
fi

# Turns efficiency (0.00–1.00); null when turns_max is 0
TURNS_USED="${TURNS_USED:-0}"
TURNS_MAX="${TURNS_MAX:-0}"
TURNS_EFFICIENCY="null"
if [[ "${TURNS_MAX}" -gt 0 ]]; then
  TURNS_EFFICIENCY=$(awk "BEGIN {printf \"%.2f\", ${TURNS_USED}/${TURNS_MAX}}")
fi

# MCP servers as JSON array
MCP_SERVERS_JSON="[]"
if [[ -n "${MCP_SERVERS:-}" ]]; then
  MCP_SERVERS_JSON=$(printf '%s' "${MCP_SERVERS}" \
    | awk -F',' '{printf "["; for(i=1;i<=NF;i++){if(i>1)printf ","; printf "\"%s\"",$i}; printf "]"}')
fi

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
  "model":              "${MODEL:-}",
  "mcp_servers":        ${MCP_SERVERS_JSON},
  "timestamp_start":    "${TIMESTAMP_START}",
  "timestamp_end":      "${TIMESTAMP_END}",
  "duration_seconds":   ${DURATION_SECONDS},
  "turns_used":         ${TURNS_USED:-0},
  "turns_max":          ${TURNS_MAX:-0},
  "turns_efficiency":   ${TURNS_EFFICIENCY},
  "retry_count":        ${RETRY_COUNT},
  "outcome":            "${OUTCOME}",
  "weekly_count_after": ${WEEKLY_COUNT_AFTER}
}
EOF
