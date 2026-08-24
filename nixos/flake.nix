# @req: REQ-87
#
# NixOS flake for the a2t-mrv production VM.
#
# Deploy:
#   cd nixos
#   nixos-rebuild switch --flake .#a2t-mrv --target-host root@<elastic-ip> --build-host localhost
#
# Test (requires KVM):
#   nix build .#checks.x86_64-linux.smoke
{
  description = "a2t-mrv production VM — livedata on NixOS with self-hosted Postgres";

  inputs = {
    # Stable channel pinned to 25.05. Provides PostgreSQL 16, PostGIS, TimescaleDB,
    # Caddy, Elixir 1.18/OTP 27, tailwindcss, and esbuild — everything needed.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.a2t-mrv = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          # Absolute path to the livedata/ Phoenix app inside the repo.
          # Passed as a module arg so modules don't need to hard-code relative paths.
          livedataSrc = self + "/livedata";
        };
        modules = [ ./configuration.nix ];
      };

      # nixosTest smoke check. Run locally with:
      #   nix build .#checks.x86_64-linux.smoke
      # Requires KVM. Cannot run in the Hall CI runner — see PR description.
      checks.${system}.smoke = pkgs.nixosTest (import ./tests/smoke.nix {
        inherit pkgs;
        inherit (nixpkgs) lib;
        nixosModule = ./configuration.nix;
        inherit self;
      });
    };
}
