# docker/

## Why this exists

Hall automata dispatched via `.hall-contract.yaml` run inside a container image specified by the target repository. All such containers share a common infrastructure layer: Node.js 20 for MCP server tooling, `gh` for the GitHub MCP server, `git`, `jq`, `yq`, and `unzip` for automation utilities, and runner user at UID 1001 so Claude Code can operate without root.

This image is that layer. Target repos extend `FROM ghcr.io/mockasort-studio/hall-dispatch-base-image` and add only repo-specific runtimes on top.

## Image

```
ghcr.io/mockasort-studio/hall-dispatch-base-image:latest
```

Built and pushed automatically on push to `main` when `docker/Dockerfile` or `docker/entrypoint.sh` changes, via `.github/workflows/base-image.yml`.

## Contents

| Tool | Version | Purpose |
|------|---------|---------|
| Node.js | 20 LTS | MCP server tooling |
| gh | latest | GitHub API automation |
| git | latest | Source control |
| jq | latest | JSON processing |
| yq | latest | YAML processing |
| unzip | latest | Archive extraction |

Runner user `runner` is present at UID 1001. `safe.directory *` is set system-wide so git operates correctly when the workspace is mounted by GHA.

## Extending

In your target repo's `docker/Dockerfile`:

```dockerfile
FROM ghcr.io/mockasort-studio/hall-dispatch-base-image:latest

# add repo-specific layers here
```

Pair with a `.hall-contract.yaml` at the repo root:

```yaml
image: ghcr.io/your-org/your-repo-env:latest
```
