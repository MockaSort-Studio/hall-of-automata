#!/usr/bin/env bash
# Resolves retry count from task memory and decides whether to escalate.
# Required env: MEMORY, MAX_RETRIES
# Outputs: escalate, count, new-count
set -euo pipefail

if [ -n "$MEMORY" ] && [ "$MEMORY" != '{}' ]; then
  COUNT=$(printf '%s' "$MEMORY" | jq -r '.retry_count // 0')
else
  COUNT=0
fi
NEW_COUNT=$((COUNT + 1))

if [ "$COUNT" -ge "$MAX_RETRIES" ]; then
  echo "escalate=true"      >> "$GITHUB_OUTPUT"
else
  echo "escalate=false"     >> "$GITHUB_OUTPUT"
fi
echo "count=$COUNT"         >> "$GITHUB_OUTPUT"
echo "new-count=$NEW_COUNT" >> "$GITHUB_OUTPUT"
