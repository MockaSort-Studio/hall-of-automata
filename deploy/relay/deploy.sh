#!/usr/bin/env bash
# deploy.sh — build and deploy the Hall relay to any Linux VPS over SSH.
# Usage: ./deploy.sh <vps-host>
# CI:    invoked by .github/workflows/deploy.yml on push to main.
#
# Required env vars (never stored in repo — inject via CI secrets or shell):
#   WEBHOOK_SECRET, APP_ID, APP_PRIVATE_KEY
#
# Optional:
#   HALL_OPERATOR      (default: MockaSort-Studio)
#   HALL_REPO          (default: hall-of-automata)
#   HALL_REF           (default: main)
#   RELAY_DOMAIN       (default: hall.relay.mockasort-studio.eu)
#   RELAY_ADMIN_EMAIL  (default: mockasortstudio@gmail.com)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.secrets.env
[ -f "${SCRIPT_DIR}/.secrets.env" ] && source "${SCRIPT_DIR}/.secrets.env"

HOST="${1:-${VPS_HOST:-${RELAY_HOST:?'Pass VPS host as $1 or set $VPS_HOST'}}}"

echo "=== Hall Relay — deploy ==="

echo "→ Checking required secrets..."
for var in WEBHOOK_SECRET APP_ID APP_PRIVATE_KEY; do
  [[ -z "${!var:-}" ]] && { echo "ERROR: $var is not set"; exit 1; }
done

echo "→ Syncing relay source to $HOST..."
rsync -az --exclude='.secrets.env' --exclude='node_modules' \
  "${SCRIPT_DIR}/" "deploy@${HOST}:~/relay/"

# Encode the private key as base64 for safe transport over SSH heredoc.
# index.js expects \n-escaped PEM; base64 avoids heredoc breakage on newlines.
ENCODED_KEY=$(echo "${APP_PRIVATE_KEY}" | base64 -w0)

echo "→ Building and starting on $HOST..."
ssh "deploy@${HOST}" bash << REMOTE
  set -euo pipefail
  cd ~/relay

  # Decode key and convert newlines to \n literals (index.js reverses this)
  KEY=\$(echo '${ENCODED_KEY}' | base64 -d | awk '{printf "%s\\\\n", \$0}')

  # Write runtime env file — never persisted in repo
  cat > .env << ENV
WEBHOOK_SECRET=${WEBHOOK_SECRET}
APP_ID=${APP_ID}
APP_PRIVATE_KEY="\${KEY}"
HALL_OPERATOR=${HALL_OPERATOR:-MockaSort-Studio}
HALL_REPO=${HALL_REPO:-hall-of-automata}
HALL_REF=${HALL_REF:-main}
RELAY_DOMAIN=${RELAY_DOMAIN:-hall.relay.mockasort-studio.eu}
RELAY_ADMIN_EMAIL=${RELAY_ADMIN_EMAIL:-mockasortstudio@gmail.com}
ENV
  chmod 600 .env

  # Build via compose so it manages its own image correctly
  docker compose build --no-cache relay

  # Bring up relay + caddy, force-recreate to pick up new image
  docker compose up -d --force-recreate --remove-orphans

  echo "→ Waiting for relay..."
  sleep 5
  curl -sf http://localhost:3000/health && echo " healthy" || { echo " unhealthy — check logs"; docker compose logs relay; exit 1; }
REMOTE

echo ""
echo "=== Deploy complete ==="
echo "Relay health:   https://${HOST}/health"
echo "Webhook URL:    https://${HOST}/webhook"
echo ""
echo "Register this URL in the Hall GitHub App webhook settings."
echo "Required events: Issues, Issue comments, Installation, Release, Repository"
