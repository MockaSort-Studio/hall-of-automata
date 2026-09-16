# Verifies internal wiring of the storage module without real AWS calls.
# Requires Terraform >= 1.11.0 (mock_provider support).

mock_provider "aws" {}

variables {
  bucket_name           = "a2t-mrv-crcf-test"
  ec2_instance_role_arn = ""
  days_to_warm          = 30
  days_to_cold          = 90
  tags                  = { Environment = "test" }
}

run "public_access_fully_blocked" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.main.block_public_acls == true
    error_message = "block_public_acls must be true"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.main.block_public_policy == true
    error_message = "block_public_policy must be true"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.main.ignore_public_acls == true
    error_message = "ignore_public_acls must be true"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.main.restrict_public_buckets == true
    error_message = "restrict_public_buckets must be true"
  }
}

run "versioning_enabled" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.main.versioning_configuration[0].status == "Enabled"
    error_message = "Bucket versioning must be Enabled"
  }
}

run "encryption_is_sse_s3" {
  command = plan

  assert {
    condition = anytrue([
      for r in aws_s3_bucket_server_side_encryption_configuration.main.rule :
      anytrue([for a in r.apply_server_side_encryption_by_default : a.sse_algorithm == "AES256"])
    ])
    error_message = "SSE algorithm must be AES256 (SSE-S3)"
  }
}

run "lifecycle_transitions_to_warm" {
  command = plan

  assert {
    condition = anytrue([
      for rule in aws_s3_bucket_lifecycle_configuration.main.rule :
      anytrue([for t in rule.transition : t.days == 30 && t.storage_class == "STANDARD_IA"])
    ])
    error_message = "Lifecycle must transition to STANDARD_IA at 30 days (warm tier)"
  }
}

run "lifecycle_transitions_to_cold" {
  command = plan

  assert {
    condition = anytrue([
      for rule in aws_s3_bucket_lifecycle_configuration.main.rule :
      anytrue([for t in rule.transition : t.days == 90 && t.storage_class == "GLACIER"])
    ])
    error_message = "Lifecycle must transition to GLACIER at 90 days (cold tier)"
  }
}

run "no_bucket_policy_without_role_arn" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_policy.main) == 0
    error_message = "Bucket policy must not be created when ec2_instance_role_arn is empty"
  }
}

run "bucket_policy_created_with_role_arn" {
  command = plan

  variables {
    create_bucket_policy  = true
    ec2_instance_role_arn = "arn:aws:iam::123456789012:role/a2t-mrv-ec2-role"
  }

  assert {
    condition     = length(aws_s3_bucket_policy.main) == 1
    error_message = "Bucket policy must be created when create_bucket_policy is true"
  }
}

run "lifecycle_rule_is_enabled" {
  command = plan

  assert {
    condition     = anytrue([for rule in aws_s3_bucket_lifecycle_configuration.main.rule : rule.status == "Enabled"])
    error_message = "CRCF retention tiering lifecycle rule must be Enabled"
  }
}

