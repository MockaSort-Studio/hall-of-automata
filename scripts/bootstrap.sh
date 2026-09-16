#!/usr/bin/env bash
# One-time setup: creates the GitHub OIDC provider, GitHub Actions IAM roles,
# and the CI IAM user in AWS. Run this once with admin credentials before CI
# is wired up, and whenever the bootstrap config changes.
#
# Prerequisites:
#   - AWS CLI configured with admin credentials (aws configure, env vars, or SSO)
#   - Terraform >= 1.7 installed
#   - Admin permissions: iam:*, sts:GetCallerIdentity
#
# Usage:
#   ./scripts/bootstrap.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_DIR="$REPO_ROOT/terraform/bootstrap"

# ── Preflight ──────────────────────────────────────────────────────────────────
echo "==> Checking prerequisites..."

command -v aws       &>/dev/null || { echo "ERROR: aws CLI not found."; exit 1; }
command -v terraform &>/dev/null || { echo "ERROR: terraform not found."; exit 1; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || {
  echo "ERROR: aws sts get-caller-identity failed — check your AWS credentials."
  exit 1
}
REGION=$(aws configure get region 2>/dev/null || echo "eu-north-1")

echo "    Account : $ACCOUNT_ID"
echo "    Region  : $REGION"
echo "    Identity: $(aws sts get-caller-identity --query Arn --output text)"
echo ""
read -rp "Proceed with bootstrap apply? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ── Terraform apply ────────────────────────────────────────────────────────────
echo ""
echo "==> Running terraform bootstrap..."
cd "$BOOTSTRAP_DIR"

terraform init -input=false

terraform apply \
  -var="account_id=$ACCOUNT_ID" \
  -var="aws_region=$REGION" \
  -input=false

# ── Post-apply instructions ────────────────────────────────────────────────────
echo ""
echo "==> Bootstrap complete."
echo ""
echo "    Created resources:"
echo "      - IAM OIDC provider: token.actions.githubusercontent.com"
echo "      - IAM role: arn:aws:iam::${ACCOUNT_ID}:role/a2t-mrv-github-terraform"
echo "      - IAM role: arn:aws:iam::${ACCOUNT_ID}:role/a2t-mrv-github-deploy"
echo "      - IAM user: a2t-mrv-terraform-ci (legacy, for local dev use)"
echo ""
echo "    Next steps:"
echo "      1. If AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY are set in GitHub"
echo "         Actions secrets, you can now delete them — the workflows use OIDC."
echo "      2. Push to main to trigger a Terraform apply via the terraform workflow,"
echo "         which will wire the deploy role into the S3 bucket policy."
echo "      3. For local development with Terraform, create a personal access key"
echo "         for a2t-mrv-terraform-ci in the AWS Console if needed."
