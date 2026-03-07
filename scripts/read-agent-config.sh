#!/usr/bin/env bash
# Reads agent config from agents.yml and writes outputs to GITHUB_OUTPUT.
# Required env: AGENT
# Outputs: max-turns, team-slug, keeper, max-retries
set -euo pipefail

MAX_TURNS=$(yq ".agents.${AGENT}.max_turns // 40" .hall/agents.yml)
TEAM=$(yq ".agents.${AGENT}.teams[0]" .hall/agents.yml)
KEEPER=$(yq ".agents.${AGENT}.keeper" .hall/agents.yml)
MAX_RETRIES=$(yq ".agents.${AGENT}.max_retries // 3" .hall/agents.yml)

echo "max-turns=$MAX_TURNS"     >> "$GITHUB_OUTPUT"
echo "team-slug=$TEAM"          >> "$GITHUB_OUTPUT"
echo "keeper=$KEEPER"           >> "$GITHUB_OUTPUT"
echo "max-retries=$MAX_RETRIES" >> "$GITHUB_OUTPUT"
