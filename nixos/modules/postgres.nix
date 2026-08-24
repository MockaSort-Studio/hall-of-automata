# @req: REQ-87
#
# PostgreSQL 16 with PostGIS and TimescaleDB.
#
# Data directory lives on the EBS gp3 volume attached by Terraform at /dev/sdf.
# On Nitro-based instances (t3.*, m5.*, c5.*, ...) that device appears as
# /dev/nvme1n1 (root is nvme0n1). On older Xen instances (/dev/xvdf), update
# ebsDevice below.
#
# First-boot note: if the EBS volume is new (unformatted), format it before
# switching to this config:
#   mkfs.ext4 /dev/nvme1n1
#   e2label /dev/nvme1n1 postgres-data
#
{ config, pkgs, lib, ... }:

let
  # AWS Nitro NVMe mapping: Terraform device_name = "/dev/sdf" → /dev/nvme1n1.
  # Change to "/dev/xvdf" for Xen instance families (t2, m3, c3).
  ebsDevice = "/dev/nvme1n1";
in
{
  # Mount the EBS data volume. NixOS generates a systemd .mount unit from this
  # declaration and automatically orders postgresql.service to start after it.
  fileSystems."/var/lib/postgresql" = {
    device = ebsDevice;
    fsType = "ext4";
    options = [ "defaults" "noatime" ];
  };

  services.postgresql = {
    enable = true;

    # PostgreSQL 16 — matches the version used in development (devenv.nix).
    package = pkgs.postgresql_16;

    # dataDir defaults to /var/lib/postgresql/${version} — under the EBS mount.
    # Declaring it explicitly makes the dependency clear.
    dataDir = "/var/lib/postgresql/16";

    # PostGIS and TimescaleDB loaded as pg extensions.
    # timescaledb is Timescale-licensed (unfree); nixpkgs.config.allowUnfree
    # must be true in configuration.nix.
    extraPlugins = ps: with ps; [
      postgis
      timescaledb
    ];

    settings = {
      # TimescaleDB hooks into the query planner and must load at server start.
      shared_preload_libraries = "timescaledb";

      # Reasonable defaults for a t3.small (2 vCPU, 2 GiB RAM).
      shared_buffers = "256MB";
      work_mem = "4MB";
      max_connections = 50;
    };

    # pg_hba.conf: the livedata user connects via Unix socket, no password.
    # All other local connections are rejected.
    authentication = lib.mkOverride 10 ''
      local   livedata        livedata                        trust
      local   all             all                             reject
      host    all             all             127.0.0.1/32    reject
      host    all             all             ::1/128         reject
    '';

    # Create the role and database on first initialisation.
    # This script runs once when the data directory is first created (initdb).
    initialScript = pkgs.writeText "postgres-init.sql" ''
      CREATE ROLE livedata WITH LOGIN;
      CREATE DATABASE livedata OWNER livedata;
      \connect livedata
      CREATE EXTENSION IF NOT EXISTS postgis;
      CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
    '';
  };
}
