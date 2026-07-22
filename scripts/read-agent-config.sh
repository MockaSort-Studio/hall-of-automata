#!/usr/bin/env bash
# Reads agent config from agents.json and writes outputs to GITHUB_OUTPUT.
# Required env: AGENT
# Outputs: agent-valid, team-slug, author, max-retries, model
set -euo pipefail

EXISTS=$(jq -r --arg agent "${AGENT}" 'has("agents") and (.agents | has($agent))' .hall/agents.json)

if [[ "$EXISTS" != "true" ]]; then
  echo "agent-valid=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

TEAM=$(jq -r --arg agent "${AGENT}" '.agents[$agent].teams[0]' .hall/agents.json)
AUTHOR=$(jq -r --arg agent "${AGENT}" '.agents[$agent].author' .hall/agents.json)
MAX_RETRIES=$(jq -r --arg agent "${AGENT}" '.agents[$agent].max_retries // 3' .hall/agents.json)
MODEL=$(jq -r --arg agent "${AGENT}" '.agents[$agent].model // ""' .hall/agents.json)

echo "agent-valid=true"         >> "$GITHUB_OUTPUT"
echo "team-slug=$TEAM"          >> "$GITHUB_OUTPUT"
echo "author=$AUTHOR"           >> "$GITHUB_OUTPUT"
echo "max-retries=$MAX_RETRIES" >> "$GITHUB_OUTPUT"
echo "model=$MODEL"             >> "$GITHUB_OUTPUT"
