#!/usr/bin/env bash
# Reads agent config from agents.yml and writes outputs to GITHUB_OUTPUT.
# Required env: AGENT
# Outputs: agent-valid, team-slug, author, max-retries, model
set -euo pipefail

EXISTS=$(yq "has(\"agents\") and (.agents | has(\"${AGENT}\"))" .hall/agents.yml)

if [[ "$EXISTS" != "true" ]]; then
  echo "agent-valid=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

TEAM=$(yq ".agents.${AGENT}.teams[0]" .hall/agents.yml)
AUTHOR=$(yq ".agents.${AGENT}.author" .hall/agents.yml)
MAX_RETRIES=$(yq ".agents.${AGENT}.max_retries // 3" .hall/agents.yml)
MODEL=$(yq ".agents.${AGENT}.model // \"\"" .hall/agents.yml)

echo "agent-valid=true"         >> "$GITHUB_OUTPUT"
echo "team-slug=$TEAM"          >> "$GITHUB_OUTPUT"
echo "author=$AUTHOR"           >> "$GITHUB_OUTPUT"
echo "max-retries=$MAX_RETRIES" >> "$GITHUB_OUTPUT"
echo "model=$MODEL"             >> "$GITHUB_OUTPUT"
