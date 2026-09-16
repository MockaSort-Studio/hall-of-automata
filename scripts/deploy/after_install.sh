#!/usr/bin/env bash
# AfterInstall: extract the Mix release, fetch secrets, write the env file,
# and write/refresh the systemd unit.
set -euo pipefail

# Region written by user_data at first boot — no IMDS dependency.
REGION=$(cat /etc/livedata/region)

# Secret names written by user_data from Terraform variables — no hardcoding.
# shellcheck source=/dev/null
source /etc/livedata/secrets.conf

get_ssm() {
  aws ssm get-parameter \
    --name "$1" --region "$REGION" \
    --query 'Parameter.Value' --output text
}

# ── Download and extract release ──────────────────────────────────────────────
echo "Downloading Mix release from S3..."
REVISIONS_BUCKET=$(get_ssm /a2t-mrv/runtime/revisions-bucket)
mkdir -p /opt/livedata/install
aws s3 cp "s3://${REVISIONS_BUCKET}/releases/livedata.tar.gz" \
  /opt/livedata/install/livedata.tar.gz --region "$REGION"

echo "Extracting Mix release..."
rm -rf /opt/livedata/current
mkdir -p /opt/livedata/current
tar -xzf /opt/livedata/install/livedata.tar.gz \
  -C /opt/livedata/current --strip-components=1
chown -R livedata:livedata /opt/livedata/current

# ── Fetch AWS RDS CA bundle ───────────────────────────────────────────────────
# The system CA bundle on AL2023 does not contain Amazon's RDS CA. Download the
# AWS-provided trust store using the URL stored in SSM (same pattern as other
# runtime config). The bundle is public; the URL lives in SSM for configurability.
echo "Fetching RDS CA bundle..."
DB_SSL_CA_URL=$(get_ssm /a2t-mrv/runtime/database-ssl-ca-url)
curl -fsSL "$DB_SSL_CA_URL" -o /etc/livedata/rds-ca-bundle.pem
chmod 644 /etc/livedata/rds-ca-bundle.pem

# ── Fetch secrets from Secrets Manager ───────────────────────────────────────
# Use the AWS CLI (proven to work with the instance profile) to fetch
# credentials once at deploy time. They are written to the env file and read
# by the application as plain env vars — no Secrets Manager calls at app boot.
echo "Fetching DB credentials (${DB_CREDENTIALS_SECRET})..."
DATABASE_URL_MAIN=$(aws secretsmanager get-secret-value \
  --secret-id "$DB_CREDENTIALS_SECRET" --region "$REGION" \
  --query SecretString --output text \
  | python3 -c "
import json, sys
from urllib.parse import quote
d = json.load(sys.stdin)
u = quote(str(d['username']), safe='')
p = quote(str(d['password']), safe='')
print(f'ecto://{u}:{p}@{d[\"host\"]}:{d[\"port\"]}/{d[\"dbname\"]}')
")

echo "Fetching app secrets (${SECRET_KEY_BASE_SECRET})..."
SECRET_KEY_BASE_VAL=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_KEY_BASE_SECRET" --region "$REGION" \
  --query SecretString --output text)

# ── Fetch non-secret runtime config from SSM ──────────────────────────────────
echo "Fetching runtime config from SSM..."
PHX_HOST=$(get_ssm /a2t-mrv/runtime/phx-host)
COGNITO_POOL_ID=$(get_ssm /a2t-mrv/runtime/cognito-user-pool-id)
COGNITO_DOMAIN_PREFIX=$(get_ssm /a2t-mrv/runtime/cognito-domain-prefix)

# ── Write env file ────────────────────────────────────────────────────────────
# Non-secret values use a heredoc; DATABASE_URL_MAIN and SECRET_KEY_BASE are
# appended with printf to handle any special characters safely.
echo "Writing /etc/livedata/env..."
mkdir -p /etc/livedata
chown root:livedata /etc/livedata
chmod 750 /etc/livedata
cat > /etc/livedata/env << EOF
PHX_SERVER=true
PHX_HOST=${PHX_HOST}
PORT=4000
DATABASE_SSL=true
DATABASE_SSL_CACERTFILE=/etc/livedata/rds-ca-bundle.pem
POOL_SIZE=5
COGNITO_USER_POOL_ID=${COGNITO_POOL_ID}
COGNITO_DOMAIN_PREFIX=${COGNITO_DOMAIN_PREFIX}
COGNITO_REGION=${REGION}
LD_LIBRARY_PATH=/opt/livedata/current/lib/openssl
EOF
# Append secrets with printf to safely handle any special characters
printf 'DATABASE_URL_MAIN=%s\n' "$DATABASE_URL_MAIN" >> /etc/livedata/env
printf 'SECRET_KEY_BASE=%s\n' "$SECRET_KEY_BASE_VAL" >> /etc/livedata/env
chmod 600 /etc/livedata/env

# ── Write systemd unit ────────────────────────────────────────────────────────
echo "Writing systemd unit..."
cat > /etc/systemd/system/livedata.service << 'UNIT'
[Unit]
Description=Livedata Phoenix Application
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
User=livedata
Group=livedata
WorkingDirectory=/opt/livedata/current
EnvironmentFile=/etc/livedata/env
ExecStart=/opt/livedata/current/bin/livedata start
ExecStop=/opt/livedata/current/bin/livedata stop
Restart=on-failure
RestartSec=5
SyslogIdentifier=livedata

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable livedata

# ── Install and configure Caddy ───────────────────────────────────────────────
# Caddy handles TLS automatically via ACME (port 80 challenge). Installed on
# first deploy via static binary from GitHub; subsequent deploys only update
# the Caddyfile and reload. COPR is not used — it has no AL2023 repository.
if ! command -v caddy &>/dev/null; then
  echo "Installing Caddy..."
  CADDY_VERSION="2.11.4"
  curl -fsSL "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_amd64.tar.gz" \
    | tar -xz -C /usr/local/bin caddy
  chmod 755 /usr/local/bin/caddy
  setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/caddy

  id caddy &>/dev/null || useradd --system --home-dir /var/lib/caddy --no-create-home --shell /sbin/nologin caddy
  mkdir -p /var/lib/caddy
  chown caddy:caddy /var/lib/caddy

  cat > /etc/systemd/system/caddy.service << 'CADDYUNIT'
[Unit]
Description=Caddy
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
Environment=HOME=/var/lib/caddy
StateDirectory=caddy
LogsDirectory=caddy
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
CADDYUNIT

  systemctl daemon-reload
  systemctl enable caddy
fi

echo "Writing Caddyfile..."
mkdir -p /etc/caddy
cat > /etc/caddy/Caddyfile << CADDYEOF
${PHX_HOST} {
    reverse_proxy localhost:4000
}
CADDYEOF

echo "AfterInstall complete."
