# Working in `nixos/`

Guidelines for the NixOS configuration under [`nixos/`](../../nixos/): the Nix/NixOS conventions and idioms used in it. This file is imported by [`CLAUDE.md`](../../CLAUDE.md). Cross-cutting rules live in [general.md](general.md); deployment context in [deployment.md](deployment.md).

## Overview

`nixos/` is a Nix flake that defines the full NixOS system configuration for the a2t-mrv production VM. It is separate from `docker/` (the CI / Hall-agent environment) and from `livedata/Dockerfile` (the Render deployment). See [deployment.md](deployment.md) for context on why multiple deployment targets exist.

## Conventions

- Format `.nix` files with `nixpkgs-fmt` or `alejandra` before committing.
- All NixOS-specific module options live under the `a2t-mrv` namespace (`options.a2t-mrv.*`) to avoid colliding with upstream nixpkgs options.
- Keep `@req: REQ-87` (and successor requirement IDs) on all module files as per [general.md § Requirement traceability](general.md#requirement-traceability).
- `lib.fakeHash` in `fetchMixDeps` is intentional on first commit. The operator computes the real hash with `nix build`; see `nixos/README.md`.

## Files not committed to the Nix store / repo

- `/run/secrets/livedata.env` — `SECRET_KEY_BASE` and `PHX_HOST`. Created by the operator on the target VM; never committed.
- The EBS volume itself and its data — managed by Terraform and PostgreSQL.

## Nixpkgs channel

`nixos/flake.nix` pins to `nixos-25.05` (stable). This is intentionally different from `devenv.nix`'s `cachix/devenv-nixpkgs/rolling`. The stable channel is appropriate for a production server; rolling is appropriate for a development shell.

When nixpkgs needs to be updated (e.g. for a security fix), update the `nixpkgs.url` in `nixos/flake.nix` and run `nix flake update`.

## Adding NixOS modules

Each sub-concern gets its own file in `nixos/modules/`:

```
nixos/modules/
  caddy.nix      # reverse proxy
  livedata.nix   # Mix release + systemd service
  postgres.nix   # PostgreSQL + extensions + EBS mount
```

A new module must:
1. Begin with `# @req: REQ-<N>`
2. Define its options (if any) under `options.a2t-mrv.*`
3. Stay under ~200 lines (hard ceiling per coding standards)
4. Be imported in `nixos/configuration.nix`
