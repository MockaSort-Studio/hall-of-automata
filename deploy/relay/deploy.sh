#!/usr/bin/env bash
# Deploys the Hall webhook relay to Fly.io.
# Run from repo root: bash deploy/relay/deploy.sh
# Prerequisites: flyctl installed and authenticated (fly auth login)
set -euo pipefail

cd "$(dirname "$0")"

echo "=== Hall Relay — Fly.io deploy ==="

# First-time setup: create the app if it doesn't exist
if ! fly status --app hall-relay &>/dev/null; then
  echo "→ Creating Fly app..."
  fly launch --name hall-relay --region lhr --no-deploy --copy-config
fi

# Set required secrets if not already present
echo ""
echo "→ Checking secrets..."

MISSING=()
for VAR in WEBHOOK_SECRET GITHUB_TOKEN; do
  if ! fly secrets list --app hall-relay 2>/dev/null | grep -q "^${VAR}"; then
    MISSING+=("$VAR")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo ""
  echo "The following secrets are required but not set:"
  for VAR in "${MISSING[@]}"; do
    echo "  - $VAR"
  done
  echo ""
  echo "Set them with:"
  echo "  fly secrets set \\"
  echo "    WEBHOOK_SECRET=\"\$(openssl rand -hex 32)\" \\"
  echo "    GITHUB_TOKEN=\"<fine-grained PAT: actions:write on hall-of-automata>\" \\"
  echo "    HALL_OWNER=\"MockaSort-Studio\" \\"
  echo "    HALL_REPO=\"hall-of-automata\""
  echo ""
  echo "Then re-run this script."
  exit 1
fi

echo "→ Deploying..."
fly deploy --app hall-relay

echo ""
echo "=== Deploy complete ==="
echo "Relay URL: https://hall-relay.fly.dev/webhook"
echo ""
echo "Register this URL as an org webhook in GitHub:"
echo "  https://github.com/organizations/MockaSort-Studio/settings/hooks"
echo "  Events: Issues, Issue comments"
echo "  Content type: application/json"
echo "  Secret: (the WEBHOOK_SECRET you set above)"
