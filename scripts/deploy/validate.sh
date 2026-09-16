#!/usr/bin/env bash
# ValidateService: confirm the app is serving HTTP on localhost.
# Retries for up to 2 minutes to allow for startup and migration time.
# A non-zero exit triggers automatic rollback via the deployment group's
# AutoRollbackConfiguration.
set -euo pipefail

URL="http://localhost:4000/"

for i in $(seq 1 12); do
  STATUS=$(curl -sSo /dev/null -w '%{http_code}' --max-time 10 "$URL" || true)
  case "$STATUS" in
    2[0-9][0-9]|301|302|303)
      echo "Health check passed — localhost:4000 returned HTTP $STATUS."
      exit 0
      ;;
    *)
      echo "Attempt $i/12 — HTTP $STATUS, waiting 10 s..."
      sleep 10
      ;;
  esac
done

echo "Health check failed — localhost:4000 did not respond within 2 minutes."
journalctl -u livedata --no-pager -n 50 || true
exit 1
