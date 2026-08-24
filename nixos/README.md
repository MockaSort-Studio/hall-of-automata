# nixos — NixOS configuration for the a2t-mrv production VM

NixOS system configuration for the EC2 VM provisioned by the Terraform module under `terraform/`. Implements KR 6.2 (#87): livedata runs as a NixOS-native service with self-hosted PostgreSQL, PostGIS, TimescaleDB, and Caddy terminating HTTPS.

## Architecture

```
Internet → :443 Caddy (ACME/TLS) → :4000 livedata (systemd) → PostgreSQL 16 (Unix socket) → EBS gp3 (/dev/nvme1n1)
```

No Docker anywhere in this path.

## Pre-deployment checklist

These steps must be completed before running `nixos-rebuild switch`.

### 1. Compute the Hex deps hash

The livedata Nix derivation pre-fetches all Mix/Hex dependencies as a fixed-output derivation. The hash placeholder in `modules/livedata.nix` must be replaced with the real hash:

```sh
cd nixos
# Attempt a build — it will fail and print the correct hash:
nix build .#nixosConfigurations.a2t-mrv.config.system.build.toplevel 2>&1 | grep 'got:'
# Output example:
#   got:    sha256-abc123...
```

Replace `lib.fakeHash` in `modules/livedata.nix` (the `mixFodDeps` derivation) with the printed hash. Re-run `nix build` — it should proceed.

### 2. DNS

Point the domain's A record at the Elastic IP from:

```sh
cd terraform && terraform output public_ip
```

Caddy performs an ACME HTTP-01 challenge on first start; it will fail if DNS doesn't resolve before the service starts.

### 3. Secrets file on the target VM

SSH into the VM and create the secrets file (once, not managed by Nix):

```sh
ssh root@<elastic-ip>
mkdir -p /run/secrets
printf 'SECRET_KEY_BASE=%s\nPHX_HOST=%s\n' \
  "$(openssl rand -base64 48)" \
  "your.domain.example.com" \
  > /run/secrets/livedata.env
chmod 600 /run/secrets/livedata.env
```

`SECRET_KEY_BASE` must be at least 64 bytes. `PHX_HOST` must match the domain set in `configuration.nix` (`a2t-mrv.domain`).

### 4. Format the EBS volume (first time only)

If the EBS data volume is new (blank), format it before applying the NixOS config:

```sh
ssh root@<elastic-ip>
# Verify device name (Nitro instances: nvme1n1; Xen: xvdf):
lsblk
mkfs.ext4 /dev/nvme1n1
```

## Deploying

From the repository root, with `nix` and `nixos-rebuild` available:

```sh
cd nixos
nixos-rebuild switch \
  --flake .#a2t-mrv \
  --target-host root@<elastic-ip> \
  --build-host localhost
```

`--build-host localhost` builds the derivation locally and copies the result to the VM, avoiding the need to install the full Nix toolchain on the instance.

## Verifying

```sh
# App responds over HTTPS
curl -sS -o /dev/null -w '%{http_code}\n' https://your.domain.example.com/
# → 200

# Services are active
ssh root@<elastic-ip> systemctl status postgresql livedata caddy

# Postgres data is on the EBS volume, not root disk
ssh root@<elastic-ip> df /var/lib/postgresql
# → /dev/nvme1n1 (or /dev/xvdf on Xen)

# No Docker
ssh root@<elastic-ip> which docker
# → not found
```

Register a project through the UI to confirm PostGIS writes succeed end-to-end.

## Running the smoke test locally

```sh
cd nixos
nix build .#checks.x86_64-linux.smoke
```

Requires KVM. Uses an in-memory tmpfs instead of a real EBS device and Caddy's internal TLS instead of ACME.

## Instance type note

The Terraform default is `t3.small` (AWS Nitro, NVMe). Nitro instances expose EBS volumes as NVMe devices: Terraform's `/dev/sdf` → `/dev/nvme1n1` on the instance. If `instance_type` is changed to a Xen family (t2, m3, c3), update `ebsDevice` in `modules/postgres.nix` to `/dev/xvdf`.
