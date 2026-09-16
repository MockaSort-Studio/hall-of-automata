
# ── EC2 IAM Role ──────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "a2t-mrv-ec2"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = var.tags
}

# ── EC2 Permissions ───────────────────────────────────────────────────────────
# Grants the instance exactly what the application needs:
#   - GetSecretValue on the three specific secrets provisioned for this deployment
#   - List + object access on the CRCF retention bucket
# The bucket ARN is constructed from var.storage_bucket_name to avoid a circular
# module dependency (storage also references this role for its bucket policy).
data "aws_iam_policy_document" "ec2_permissions" {
  statement {
    sid     = "ReadSecrets"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      var.db_credentials_secret_arn,
      var.secret_key_base_secret_arn,
      var.cognito_client_secret_arn,
    ]
  }

  statement {
    sid       = "ReadRuntimeParams"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:*:*:parameter/a2t-mrv/*"]
  }

  statement {
    sid       = "DescribeRDS"
    actions   = ["rds:DescribeDBInstances"]
    resources = ["*"]
  }

  statement {
    sid       = "CognitoAuth"
    actions   = ["cognito-idp:InitiateAuth"]
    resources = [var.cognito_user_pool_arn]
  }

  statement {
    sid       = "S3BucketList"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.storage_bucket_name}"]
  }

  statement {
    sid       = "S3ObjectAccess"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.storage_bucket_name}/*"]
  }
}

resource "aws_iam_role_policy" "ec2" {
  name   = "a2t-mrv-ec2-permissions"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_permissions.json
}

# SSM Session Manager — lets operators open a shell without an SSH key,
# and lets the CodeDeploy agent receive commands from the service endpoint.
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ── Instance Profile ──────────────────────────────────────────────────────────
resource "aws_iam_instance_profile" "ec2" {
  name = "a2t-mrv-ec2"
  role = aws_iam_role.ec2.name
  tags = var.tags
}
