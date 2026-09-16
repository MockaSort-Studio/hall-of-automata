#!/usr/bin/env bash
# ApplicationStop: gracefully stop the livedata service before the new revision
# is installed. Tolerates failure when no previous deployment exists.
set -euo pipefail
systemctl stop livedata || true
