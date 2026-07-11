#!/usr/bin/env bash
# Test: write-audit-log.sh emits token fields, not turn fields.
set -euo pipefail
cd "$(dirname "$0")/.."

export AGENT=hamlet
export AGENT_DISPATCHED=hamlet
export REROUTED=false
export REPO_OWNER=TestOrg
export REPO_NAME=test-repo
export ISSUE_NUMBER=42
export PR_NUMBER=99
export INVOKER=testuser
export TEAM_VALIDATED=team-x
export TIMESTAMP_START="2026-01-01T00:00:00Z"
export TOKEN_INPUT=12345
export TOKEN_OUTPUT=678
export RETRY_COUNT=0
export OUTCOME=pr_created
export WEEKLY_COUNT_AFTER=5

bash scripts/write-audit-log.sh

RESULT=$(cat hall-invocation-log.json)
FAILURES=0

expect_present() {
  if echo "$RESULT" | grep -q "$1"; then
    echo "  ok  $2"
  else
    echo "  FAIL $2"
    FAILURES=$(( FAILURES + 1 ))
  fi
}

expect_absent() {
  if ! echo "$RESULT" | grep -q "$1"; then
    echo "  ok  $2"
  else
    echo "  FAIL $2"
    FAILURES=$(( FAILURES + 1 ))
  fi
}

expect_present '"token_input"'      "token_input field present"
expect_present '"token_output"'     "token_output field present"
expect_present '12345'              "token_input value correct"
expect_present '678'                "token_output value correct"
expect_absent  '"turns_used"'       "turns_used absent"
expect_absent  '"turns_max"'        "turns_max absent"
expect_absent  '"turns_efficiency"' "turns_efficiency absent"
expect_present '"outcome"'          "outcome field present"
expect_present '"retry_count"'      "retry_count field present"

rm -f hall-invocation-log.json
echo ""
echo "$FAILURES failure(s)."
exit "$FAILURES"
