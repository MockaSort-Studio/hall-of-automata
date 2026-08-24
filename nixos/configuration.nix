# @req: REQ-87
#
# Top-level NixOS system configuration for the a2t-mrv production VM.
#
# Before deploying, set the actual domain below (a2t-mrv.domain) and ensure:
#   - The domain's DNS A record points at the Elastic IP from terraform output
#   - /run/secrets/livedata.env exists on the target machine (see README.md)
{ pkgs, lib, modulesPath, livedataSrc, ... }:

{
  imports = [
    # Amazon EC2 defaults: grub, cloud-init, nvme driver, SSM agent, etc.
    (modulesPath + "/virtualisation/amazon-image.nix")
    ./modules/postgres.nix
    ./modules/livedata.nix
    ./modules/caddy.nix
  ];

  # ── Domain ─────────────────────────────────────────────────────────────────
  # Replace with the actual domain before deploying.
  # The DNS A record must resolve to the VM's Elastic IP before Caddy starts
  # (ACME HTTP-01 challenge). Caddy will acquire the certificate on first start.
  a2t-mrv.domain = "livedata.example.com";

  # ── System ─────────────────────────────────────────────────────────────────
  networking.hostName = "a2t-mrv";
  time.timeZone = "UTC";

  # timescaledb is distributed under the Timescale License (unfree).
  # The app uses only create_hypertable, which the Apache-2 subset also covers,
  # but nixpkgs provides the full build. allowUnfree enables it.
  nixpkgs.config.allowUnfree = true;

  # ── SSH ────────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # ── Packages available system-wide (debugging / ops) ─────────────────────
  environment.systemPackages = with pkgs; [
    curl
    htop
    jq
    vim
  ];

  # Tracks NixOS module API version — do not change after first deploy.
  system.stateVersion = "25.05";
}
