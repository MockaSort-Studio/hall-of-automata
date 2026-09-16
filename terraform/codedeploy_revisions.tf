locals {
  revisions_bucket = var.codedeploy_revisions_bucket_name
}

resource "aws_s3_bucket" "codedeploy_revisions" {
  bucket = local.revisions_bucket
  tags   = merge(var.tags, { Name = local.revisions_bucket, Role = "codedeploy-revisions" })
}

resource "aws_s3_bucket_public_access_block" "codedeploy_revisions" {
  bucket = aws_s3_bucket.codedeploy_revisions.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codedeploy_revisions" {
  bucket = aws_s3_bucket.codedeploy_revisions.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
  }
}

# Keep the last 30 days of release artifacts; older tarballs are removed automatically.
resource "aws_s3_bucket_lifecycle_configuration" "codedeploy_revisions" {
  bucket = aws_s3_bucket.codedeploy_revisions.id

  rule {
    id     = "expire-old-revisions"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}

# EC2 instance role needs GetObject so the CodeDeploy agent can pull revision zips.
# The CI IAM user (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY in GitHub secrets) needs
# s3:PutObject and s3:ListBucket — grant those on the CI user's IAM policy separately.
resource "aws_s3_bucket_policy" "codedeploy_revisions" {
  bucket     = aws_s3_bucket.codedeploy_revisions.id
  depends_on = [aws_s3_bucket_public_access_block.codedeploy_revisions]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEC2RoleGetObject"
        Effect    = "Allow"
        Principal = { AWS = module.infra.instance_role_arn }
        Action    = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.codedeploy_revisions.arn,
          "${aws_s3_bucket.codedeploy_revisions.arn}/*",
        ]
      },
      {
        Sid    = "AllowGitHubDeployRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/a2t-mrv-github-deploy"
        }
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.codedeploy_revisions.arn,
          "${aws_s3_bucket.codedeploy_revisions.arn}/*",
        ]
      },
      {
        Sid       = "DenyNonHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.codedeploy_revisions.arn,
          "${aws_s3_bucket.codedeploy_revisions.arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
    ]
  })
}

# The instance reads this to know where to download the release tarball from S3.
resource "aws_ssm_parameter" "revisions_bucket" {
  name  = "/a2t-mrv/runtime/revisions-bucket"
  type  = "String"
  value = aws_s3_bucket.codedeploy_revisions.bucket
  tags  = var.tags
}
