#!/usr/bin/env bash
# Resolves the final token validation result from dispatch outcome and fallback probe.
# Required env: DISPATCH_OUTCOME, FALLBACK_PASSED
# Output (GITHUB_OUTPUT): test-passed=true|false
set -euo pipefail

if [[ "${DISPATCH_OUTCOME}" == "success" ]]; then
  echo "test-passed=true" >> "${GITHUB_OUTPUT}"
elif [[ "${FALLBACK_PASSED}" == "true" ]]; then
  echo "test-passed=true" >> "${GITHUB_OUTPUT}"
else
  echo "test-passed=false" >> "${GITHUB_OUTPUT}"
fi
