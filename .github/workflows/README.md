# `.github/workflows/`

CI/CD workflows for this repository.

## Sequencing model

`terraform` is the sequencer for all pushes to `main`. It fires on every
commit that touches `terraform/`, `livedata/`, `appspec.yml`, or
`scripts/deploy/`. Once its `apply` job completes, `workflow_run` triggers
`deploy-livedata`, which checks whether the commit actually touched
deploy-relevant files before proceeding. This guarantees the order
**infra first, deploy second** for any combination of changed files.

## Always-on checks

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| [`test-livedata.yml`](test-livedata.yml) | PR and merge queue (when `livedata/` changes) | Runs `mix compile --warnings-as-errors` and `mix test --warnings-as-errors` inside the env container. |
| [`check-deploy.yml`](check-deploy.yml) | PR and merge queue (when `livedata/`, `appspec.yml`, `scripts/deploy/`, or deploy workflows change) | Three pre-merge gates: shellcheck on deploy scripts, prod Mix release build, appspec.yml lint. No AWS credentials required. |
| [`loc-check.yml`](loc-check.yml) | PR and merge queue | Enforces the net-LOC diff gate — rejects PRs that exceed the configured line budget. |
| [`env-image.yml`](env-image.yml) | Push to `main` (when `docker/Dockerfile` changes) | Builds and pushes `ghcr.io/mockasort-studio/a2t-mrv-env:latest` — the CI container used for Hall agent dispatch and the `test-livedata` job. See [`docker/README.md`](../docker/README.md). |

## Production deployment

The app runs on a Terraform-provisioned EC2 instance (AL2023) deployed via
AWS CodeDeploy. Canonical references:

- **Deploy scripts and appspec:** [`scripts/deploy/`](../scripts/deploy/) and [`appspec.yml`](../appspec.yml)
- **AWS infrastructure:** [`terraform/README.md`](../../terraform/README.md)
- **Full deployment guide:** [`docs/contributing/deployment.md`](../../docs/contributing/deployment.md)

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| [`terraform.yml`](terraform.yml) | Push to `main` (terraform, livedata, appspec, or deploy scripts); PR (terraform only) | `changed` job detects whether terraform files changed. On push: `validate`/`plan` run only when terraform files changed; `apply` always runs (no-op for app-only commits). On PR: posts plan as a comment. Also enforces the no-managed-services policy check. |
| [`deploy-livedata.yml`](deploy-livedata.yml) | `workflow_run` after `terraform` completes on `main` | `check` job gates on deploy-relevant files in the triggering commit. When needed: builds a Mix release via `erlef/setup-beam` on Ubuntu 22.04 (glibc 2.35, compatible with AL2023), bundles OpenSSL libs for SM4 support, uploads release tarball to S3, creates a CodeDeploy deployment. `ValidateService` in `appspec.yml` health-checks the live endpoint; failure triggers automatic rollback. |

## PR previews

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| [`preview.yml`](preview.yml) | PR opened / synchronised / closed (when `livedata/`, `render.yaml`, or preview workflow change) | Repoints the single free-tier Render service at the PR branch (against the shared dev database); restores `main` when the PR closes. No per-PR database branches. |
