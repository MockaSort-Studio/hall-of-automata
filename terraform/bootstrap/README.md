# terraform/bootstrap

One-time setup run **by a human with admin AWS credentials**. Creates:

- GitHub OIDC identity provider (`token.actions.githubusercontent.com`)
- `a2t-mrv-github-terraform` IAM role — assumed by the `terraform` workflow via OIDC
- `a2t-mrv-github-deploy` IAM role — assumed by the `deploy-livedata` workflow via OIDC (main branch only)
- `a2t-mrv-terraform-ci` IAM user — kept for local development use

## When to run

- First-time account setup (new environment, scratch deploy)
- When the CI policy or OIDC trust config needs an update

## How to run

Use the setup script from the repo root — it detects your account ID automatically:

```sh
./scripts/bootstrap.sh
```

Prerequisites: AWS CLI configured with admin credentials, Terraform >= 1.7.

## After first run

The GitHub Actions workflows (`terraform.yml`, `deploy-livedata.yml`) use OIDC role
assumption — no static keys needed. If `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
are set in GitHub Actions secrets, delete them.

## What this does NOT manage

- The Terraform state bucket (`a2t-mrv-tfstate-<account_id>`) — bootstrapped
  automatically by the `bootstrap state bucket` step in `terraform.yml`.
- SSH key pair (`a2t-mrv-prod`) — create in EC2 → Key Pairs before the first
  `terraform apply` of the main root.
