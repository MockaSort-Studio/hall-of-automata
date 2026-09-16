locals {
  region      = var.aws_region
  account_id  = var.account_id
  github_repo = "MockaSort-Studio/a2t-mrv"
}

# ── GitHub OIDC provider ──────────────────────────────────────────────────────
# Establishes trust between GitHub Actions and AWS — no static keys needed.
# Applied once; all GitHub Actions workflows use role-to-assume after this.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = { Project = "a2t-mrv", ManagedBy = "terraform-bootstrap" }
}

# ── GitHub Actions — Terraform role ──────────────────────────────────────────
# Used by the terraform workflow (plan on PRs, apply on main).
# Trusted from any ref in the repo so PRs can run plan.
data "aws_iam_policy_document" "github_terraform_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_repo}:*"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_terraform" {
  name               = "a2t-mrv-github-terraform"
  assume_role_policy = data.aws_iam_policy_document.github_terraform_assume.json
  tags               = { Project = "a2t-mrv", ManagedBy = "terraform-bootstrap" }
}

resource "aws_iam_role_policy_attachment" "github_terraform" {
  role       = aws_iam_role.github_terraform.name
  policy_arn = aws_iam_policy.ci_services.arn
}

# ── GitHub Actions — Deploy role ──────────────────────────────────────────────
# Used by deploy-livedata workflow only. Restricted to this repo.
# Uses repo:*wildcard because workflow_run triggers produce a sub that
# does not match the ref: format produced by push triggers.
# The narrow IAM policy (S3 revision upload + CodeDeploy only) is the
# real security boundary here.
data "aws_iam_policy_document" "github_deploy_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_repo}:*"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "a2t-mrv-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_deploy_assume.json
  tags               = { Project = "a2t-mrv", ManagedBy = "terraform-bootstrap" }
}

resource "aws_iam_role_policy" "github_deploy" {
  name = "a2t-mrv-github-deploy-permissions"
  role = aws_iam_role.github_deploy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3RevisionUpload"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::a2t-mrv-codedeploy-*",
          "arn:aws:s3:::a2t-mrv-codedeploy-*/*",
        ]
      },
      {
        Sid    = "CodeDeploy"
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:GetApplicationRevision",
        ]
        Resource = "*"
      },
      {
        Sid      = "TaggingForBucketLookup"
        Effect   = "Allow"
        Action   = ["tag:GetResources"]
        Resource = "*"
      },
      {
        Sid      = "STS"
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      },
    ]
  })
}

# ── CI IAM Policy ─────────────────────────────────────────────────────────────
resource "aws_iam_policy" "ci_services" {
  name        = "a2t-mrv-terraform-ci-services"
  description = "Least-privilege policy for the a2t-mrv Terraform CI user."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IAM"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:GetRole", "iam:UpdateRole", "iam:DeleteRole",
          "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
          "iam:ListRolePolicies", "iam:ListRoleTags",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListAttachedRolePolicies",
          "iam:CreateInstanceProfile", "iam:GetInstanceProfile",
          "iam:DeleteInstanceProfile", "iam:ListInstanceProfilesForRole",
          "iam:ListInstanceProfiles",
          "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
          "iam:TagRole", "iam:UntagRole", "iam:TagInstanceProfile", "iam:UntagInstanceProfile",
          "iam:PassRole", "iam:GetPolicy", "iam:GetPolicyVersion",
          "iam:CreateServiceLinkedRole",
        ]
        Resource = "*"
      },
      {
        Sid      = "S3"
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = ["arn:aws:s3:::a2t-mrv-*", "arn:aws:s3:::a2t-mrv-*/*"]
      },
      {
        Sid    = "EC2"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs", "ec2:CreateVpc", "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute", "ec2:DescribeVpcAttribute",
          "ec2:DescribeSubnets", "ec2:CreateSubnet", "ec2:DeleteSubnet",
          "ec2:ModifySubnetAttribute",
          "ec2:DescribeInternetGateways", "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:DescribeRouteTables", "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
          "ec2:CreateRoute", "ec2:DeleteRoute",
          "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
          "ec2:DescribeSecurityGroups", "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeInstances", "ec2:RunInstances", "ec2:TerminateInstances",
          "ec2:StopInstances", "ec2:StartInstances",
          "ec2:DescribeInstanceAttribute", "ec2:ModifyInstanceAttribute",
          "ec2:DescribeInstanceCreditSpecifications",
          "ec2:DescribeInstanceTypes", "ec2:DescribeInstanceStatus",
          "ec2:DescribeImages", "ec2:DescribeAvailabilityZones",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeAddresses", "ec2:DescribeAddressesAttribute",
          "ec2:AllocateAddress", "ec2:ReleaseAddress",
          "ec2:AssociateAddress", "ec2:DisassociateAddress",
          "ec2:DescribeSubnetAttribute",
          "ec2:DescribeVolumes", "ec2:CreateVolume", "ec2:DeleteVolume",
          "ec2:AttachVolume", "ec2:DetachVolume", "ec2:ModifyVolume",
          "ec2:DescribeVolumeAttribute",
          "ec2:DescribeTags", "ec2:CreateTags", "ec2:DeleteTags",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeAccountAttributes",
        ]
        Resource = "*"
      },
      {
        Sid    = "RDS"
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance", "rds:DescribeDBInstances",
          "rds:ModifyDBInstance", "rds:DeleteDBInstance",
          "rds:CreateDBSubnetGroup", "rds:DescribeDBSubnetGroups",
          "rds:ModifyDBSubnetGroup", "rds:DeleteDBSubnetGroup",
          "rds:CreateDBParameterGroup", "rds:DescribeDBParameterGroups",
          "rds:ModifyDBParameterGroup", "rds:DeleteDBParameterGroup",
          "rds:ResetDBParameterGroup", "rds:DescribeDBParameters",
          "rds:DescribeDBInstanceAutomatedBackups", "rds:DescribeCertificates",
          "rds:AddTagsToResource", "rds:ListTagsForResource", "rds:RemoveTagsFromResource",
          "rds:DescribeDBEngineVersions", "rds:DescribeOrderableDBInstanceOptions",
        ]
        Resource = "*"
      },
      {
        Sid      = "Cognito"
        Effect   = "Allow"
        Action   = "cognito-idp:*"
        Resource = "*"
      },
      {
        Sid      = "SecretsManagerApp"
        Effect   = "Allow"
        Action   = "secretsmanager:*"
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:a2t-mrv/*"
      },
      {
        Sid    = "SecretsManagerRDS"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret", "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue", "secretsmanager:ListSecretVersionIds",
          "secretsmanager:TagResource",
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:rds!*"
      },
      {
        Sid      = "CodeDeploy"
        Effect   = "Allow"
        Action   = "codedeploy:*"
        Resource = "*"
      },
      {
        Sid    = "KMS"
        Effect = "Allow"
        Action = [
          "kms:DescribeKey", "kms:ListAliases", "kms:ListKeys",
          "kms:CreateGrant", "kms:RetireGrant", "kms:RevokeGrant", "kms:ListGrants",
          "kms:Encrypt", "kms:Decrypt",
          "kms:GenerateDataKey", "kms:GenerateDataKeyWithoutPlaintext",
          "kms:ReEncryptFrom", "kms:ReEncryptTo",
          "kms:GetKeyPolicy", "kms:GetKeyRotationStatus",
        ]
        Resource = "*"
      },
      {
        Sid    = "SSM"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath",
          "ssm:PutParameter", "ssm:DeleteParameter", "ssm:DescribeParameters",
          "ssm:ListTagsForResource", "ssm:AddTagsToResource",
          "ssm:GetServiceSetting", "ssm:UpdateServiceSetting", "ssm:ResetServiceSetting",
        ]
        Resource = [
          "arn:aws:ssm:${local.region}:${local.account_id}:parameter/a2t-mrv/*",
          "*",
        ]
      },
      {
        Sid      = "ResourceGroupsTagging"
        Effect   = "Allow"
        Action   = ["tag:GetResources"]
        Resource = "*"
      },
      {
        Sid      = "STS"
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      },
    ]
  })
}

