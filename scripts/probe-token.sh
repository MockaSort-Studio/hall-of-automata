#!/usr/bin/env bash
# Probes the Anthropic API to determine if a token is valid.
# Called as a fallback when the primary dispatch action fails, to distinguish
# a bad token (401/403) from quota exhaustion (429) or network issues (000).
#
# Required env: TOKEN (masked by caller)
# Output (GITHUB_OUTPUT):
#   passed=true   — 429 (valid token, quota exhausted)
#   passed=false  — 401/403 (bad token) or 000 (unreachable, cannot confirm)
set -euo pipefail

echo "::add-mask::${TOKEN}"
HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
  --max-time 15 \
  -X POST "https://api.anthropic.com/v1/messages" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-haiku-4-5","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}') \
  || HTTP=000

echo "probe HTTP: ${HTTP}"

# 429 = valid token, quota exhausted — pass
# 401/403 = bad token — fail
# 000 = network unreachable — inconclusive, treat as fail (cannot confirm token)
if [[ "${HTTP}" == "429" ]]; then
  echo "passed=true"  >> "${GITHUB_OUTPUT}"
else
  echo "passed=false" >> "${GITHUB_OUTPUT}"
fi
