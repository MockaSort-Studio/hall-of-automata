#!/usr/bin/env bash
# Resolves the final token validation result from dispatch outcome and token-status output.
# Required env: DISPATCH_OUTCOME, TOKEN_STATUS
# Output (GITHUB_OUTPUT): test-passed=true|false
set -euo pipefail

if [[ "${DISPATCH_OUTCOME}" == "success" ]]; then
  echo "test-passed=true" >> "${GITHUB_OUTPUT}"
elif [[ "${TOKEN_STATUS}" == "rate_limited" ]]; then
  echo "test-passed=true" >> "${GITHUB_OUTPUT}"
else
  echo "test-passed=false" >> "${GITHUB_OUTPUT}"
fi
