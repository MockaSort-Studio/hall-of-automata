# scripts/deploy/

CodeDeploy lifecycle hook scripts referenced by `appspec.yml`. Each script has a
single responsibility matching its lifecycle event.

| Script | Hook | What it does |
|---|---|---|
| `stop.sh` | ApplicationStop | `systemctl stop livedata` (tolerates not-running) |
| `before_install.sh` | BeforeInstall | Creates `livedata` system user and install directories |
| `after_install.sh` | AfterInstall | Extracts release tarball, fetches secrets from Secrets Manager, writes `/etc/livedata/env` and the systemd unit |
| `start.sh` | ApplicationStart | Runs Ecto migrations via the release eval command, then `systemctl start livedata` |
| `validate.sh` | ValidateService | Curls `http://localhost:4000/`, retries 12×10 s before failing |

## Revision structure

The deploy workflow (`deploy-livedata.yml`) bundles the revision zip as:

```
revision-<sha>.zip
├── appspec.yml
├── scripts/deploy/
│   ├── stop.sh
│   ├── before_install.sh
│   ├── after_install.sh
│   ├── start.sh
│   └── validate.sh
└── release/
    └── livedata.tar.gz   ← Mix release built in CI
```

`appspec.yml` maps `release/` → `/opt/livedata/install/` on the EC2 instance.
`after_install.sh` extracts the tarball to `/opt/livedata/current/`.

## Runtime configuration

All runtime config is stored in SSM Parameter Store at apply time by Terraform
(`/a2t-mrv/deploy/*` and `/a2t-mrv/runtime/*`). `after_install.sh` reads these
values and writes `/etc/livedata/env` (mode 600). The systemd unit reads that
file via `EnvironmentFile=`.

No files are written into this directory by the CI workflow at deploy time.
