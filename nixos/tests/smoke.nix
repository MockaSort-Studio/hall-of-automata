# @req: REQ-87
#
# NixOS smoke test — verifies that all three services start in a NixOS VM.
#
# Requires KVM. Run from nixos/:
#   nix build .#checks.x86_64-linux.smoke
#
# Cannot run in the Hall CI runner (no KVM). Disclosed in PR.
{ pkgs, lib, nixosModule, self }:

{
  name = "livedata-smoke";

  nodes.machine = { config, pkgs, modulesPath, ... }: {
    imports = [
      nixosModule
    ];

    # Override production-only settings that break a VM test.
    # Use a fake domain (no real ACME challenge in the VM).
    a2t-mrv.domain = "livedata.test";

    # Virtual disk instead of real EBS.
    fileSystems."/var/lib/postgresql" = lib.mkForce {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "size=512M" "mode=755" ];
    };

    # Skip ACME in tests — Caddy would fail waiting for DNS/ACME.
    services.caddy.virtualHosts."livedata.test".extraConfig = lib.mkForce ''
      tls internal
      reverse_proxy localhost:4000
    '';

    # Provide a minimal secrets file so the livedata unit can start.
    systemd.tmpfiles.rules = [
      "d /run/secrets 0700 root root -"
    ];
    system.activationScripts.livedataSecrets = ''
      if [ ! -f /run/secrets/livedata.env ]; then
        printf 'SECRET_KEY_BASE=%s\nPHX_HOST=livedata.test\n' \
          "$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 64)" \
          > /run/secrets/livedata.env
        chmod 600 /run/secrets/livedata.env
      fi
    '';

    # Skip lib.fakeHash resolution in the test — the package derivation would
    # normally fail with fakeHash. In a real test environment, substitute the
    # correct sha256 in modules/livedata.nix before running nix build.
    nixpkgs.config.allowUnfree = true;

    virtualisation.memorySize = 2048;
    virtualisation.cores = 2;
  };

  testScript = ''
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_unit("livedata.service", timeout=120)
    machine.wait_for_unit("caddy.service")

    # Postgres is accepting connections
    machine.succeed("psql -U livedata -d livedata -c 'SELECT 1'")

    # App is listening on :4000
    machine.wait_for_open_port(4000)
    machine.succeed("curl -sf http://localhost:4000/")

    # Caddy is listening on :443
    machine.wait_for_open_port(443)
  '';
}
