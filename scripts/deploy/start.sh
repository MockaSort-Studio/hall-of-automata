#!/usr/bin/env bash
# ApplicationStart: start the livedata service. Runs migrations before starting
# by calling the release's eval command; a failed migration aborts the deploy.
set -euo pipefail

# Run Ecto migrations using the release's built-in migrate command.
# This runs in the same environment as the service (reads /etc/livedata/env).
# Source env for the migration eval, but unset LD_LIBRARY_PATH before calling
# systemctl — systemd's own shared library requires a newer OpenSSL than the
# Ubuntu Jammy libcrypto.so.3 bundled with the release for AL2023 SM4 compat.
set -a; source /etc/livedata/env; set +a
/opt/livedata/current/bin/livedata eval "Livedata.Release.migrate()"

unset LD_LIBRARY_PATH
systemctl start livedata

# Caddy stays running across deploys; reload picks up any Caddyfile changes.
systemctl reload-or-restart caddy
