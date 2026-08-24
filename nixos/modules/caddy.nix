# @req: REQ-87
#
# Caddy reverse proxy with automatic HTTPS (ACME HTTP-01 challenge).
#
# Prerequisites before switching to this config:
#   - The DNS A record for a2t-mrv.domain must point at the Elastic IP.
#   - Ports 80 and 443 must be reachable (Security Group allows them — Terraform #86).
#
# Caddy acquires and renews its Let's Encrypt certificate automatically.
# The HTTP listener on :80 is used only for the ACME challenge redirect.
{ config, pkgs, lib, ... }:

let
  cfg = config.a2t-mrv;
in
{
  # ── Module option ─────────────────────────────────────────────────────────
  options.a2t-mrv.domain = lib.mkOption {
    type        = lib.types.str;
    description = "Public domain name for the livedata app (bare hostname, no scheme). Used by Caddy for ACME certificate acquisition and the livedata PHX_HOST env.";
    example     = "livedata.example.com";
  };

  # ── Caddy service ─────────────────────────────────────────────────────────
  config.services.caddy = {
    enable = true;

    # One virtual host. Caddy interprets a bare domain as HTTPS; it handles
    # HTTP→HTTPS redirect and ACME certificate management automatically.
    virtualHosts.${cfg.domain} = {
      extraConfig = ''
        reverse_proxy localhost:4000
      '';
    };
  };
}
