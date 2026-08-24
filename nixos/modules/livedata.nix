# @req: REQ-87
#
# livedata Phoenix app — Nix derivation + systemd service.
#
# The Mix release is built entirely inside the Nix sandbox:
#   - Hex dependencies: pre-fetched as a fixed-output derivation (fetchMixDeps)
#   - Asset tools (tailwind, esbuild): provided by nixpkgs; binaries placed at
#     the paths the Mix tasks expect, so no network download happens at build time
#
# ── First-deploy steps ─────────────────────────────────────────────────────
#
# 1. Compute the correct deps hash:
#      cd nixos && nix build .#nixosConfigurations.a2t-mrv.pkgs.livedata 2>&1 | grep 'got:'
#    The build will fail and print the actual hash. Substitute it for
#    lib.fakeHash in the mixFodDeps derivation below.
#
# 2. Create the secrets file on the target machine (once, not managed by Nix):
#      mkdir -p /run/secrets
#      printf 'SECRET_KEY_BASE=%s\nPHX_HOST=%s\n' \
#        "$(openssl rand -base64 48)" \
#        "livedata.example.com" \
#        > /run/secrets/livedata.env
#      chmod 600 /run/secrets/livedata.env
#
{ config, pkgs, lib, livedataSrc, ... }:

let
  beamPackages = pkgs.beam.packages.erlang_27;

  # All Hex and git dependencies, pre-fetched as a fixed-output derivation.
  # sha256 must be replaced with the correct hash before deploying.
  # See "First-deploy steps" above.
  mixFodDeps = beamPackages.fetchMixDeps {
    pname = "livedata-mix-deps";
    src = livedataSrc;
    version = "0.1.0";
    sha256 = lib.fakeHash;
  };

  # tailwind 4.x and esbuild 0.25.x versions declared in livedata/config/config.exs.
  # nixpkgs binaries are placed at the paths the Mix tasks expect so the sandbox
  # build does not attempt to download them from the internet.
  tailwindBin = "${pkgs.tailwindcss}/bin/tailwindcss";
  esbuildBin = "${pkgs.esbuild}/bin/esbuild";

  livedataPackage = beamPackages.mixRelease {
    pname = "livedata";
    version = "0.1.0";
    src = livedataSrc;
    inherit mixFodDeps;

    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.git      # required: heroicons is a git dep in mix.lock
    ];

    # Pre-populate the binary paths that the tailwind and esbuild Mix tasks
    # look for before falling back to a network download. The paths come from
    # Application.app_dir(:tailwind | :esbuild, "priv/<platform-binary>").
    preBuild = ''
      install -Dm755 ${tailwindBin} _build/prod/lib/tailwind-0.4.1/priv/tailwind-linux-x64
      install -Dm755 ${esbuildBin}  _build/prod/lib/esbuild-0.10.0/priv/esbuild-linux-x64
    '';

    buildPhase = ''
      runHook preBuild
      export MIX_ENV=prod
      export HOME="$TMPDIR"
      mix assets.deploy
      mix release --no-deps-check
      runHook postBuild
    '';
  };
in
{
  # ── System user ────────────────────────────────────────────────────────────
  users.users.livedata = {
    isSystemUser = true;
    group = "livedata";
    description = "livedata Phoenix application service account";
  };
  users.groups.livedata = {};

  # ── systemd service ────────────────────────────────────────────────────────
  systemd.services.livedata = {
    description = "livedata Phoenix application";

    # Start after Postgres is up; require it so this unit stops if Postgres dies.
    after    = [ "network-online.target" "postgresql.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      PHX_SERVER = "true";
      MIX_ENV    = "prod";
      # Listens on localhost only; Caddy reverse-proxies to it.
      PORT = "4000";
      # Unix socket connection to PostgreSQL — no TCP, no password.
      DATABASE_URL = "ecto://livedata@/livedata?host=/run/postgresql";
      # RELEASE_TMP must be writable (the BEAM runtime writes a cookie file there).
      RELEASE_TMP = "/run/livedata";
    };

    serviceConfig = {
      Type = "exec";
      User  = "livedata";
      Group = "livedata";

      # SECRET_KEY_BASE and PHX_HOST are sensitive; not in the Nix store.
      # The operator creates this file once on the machine — see module header.
      EnvironmentFile = "/run/secrets/livedata.env";

      # Run migrations before starting the server.
      ExecStartPre = "${livedataPackage}/bin/migrate";
      ExecStart    = "${livedataPackage}/bin/server";

      Restart    = "on-failure";
      RestartSec = "5s";

      # Creates /run/livedata owned by the service user on every start.
      RuntimeDirectory     = "livedata";
      RuntimeDirectoryMode = "0750";
    };
  };
}
