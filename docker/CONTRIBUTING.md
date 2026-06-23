# Contributing to docker/

## What lives here

- `Dockerfile` — the base image definition (`FROM ubuntu:24.04`)
- `entrypoint.sh` — minimal `exec "$@"` entrypoint
- `README.md` — what this image is and how to extend it

## Scope constraint

This image installs exactly the infrastructure Hall dispatch needs. Do not add repo-specific runtimes (language toolchains, databases, service processes) here — those belong in target-repo Dockerfiles that extend this image via `FROM ghcr.io/mockasort-studio/hall-dispatch-base-image`.

Changes to `Dockerfile` or `entrypoint.sh` trigger `.github/workflows/base-image.yml` automatically on push to `main`.

## Testing changes locally

```bash
cd docker
docker build -t hall-dispatch-base-image:local .
docker run --rm --user 1001 hall-dispatch-base-image:local node --version
docker run --rm --user 1001 hall-dispatch-base-image:local gh --version
docker run --rm --user 1001 hall-dispatch-base-image:local git config --system --list
```

## Validation checklist

- [ ] `node --version` returns 20.x
- [ ] `gh --version` returns a current release
- [ ] `git`, `jq`, `yq`, `unzip` are on PATH
- [ ] Running as UID 1001 (`id` returns `runner`)
- [ ] `git config --system --list` includes `safe.directory=*`
