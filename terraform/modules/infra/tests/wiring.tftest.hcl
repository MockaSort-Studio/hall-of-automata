# Verifies internal wiring of the infra module without any real AWS calls.
# Requires Terraform >= 1.11.0 (override_during support).

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
    }
  }

  # aws_iam_policy_document is a computed data source; the mock provider returns
  # null by default which breaks resources that reference .json. Provide a minimal
  # valid JSON so the plan can proceed and structural assertions can be tested.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }
}

variables {
  aws_region                  = "eu-west-1"
  instance_type               = "t3.small"
  key_name                    = "test-key"
  ssh_cidr_blocks             = ["10.0.0.0/8"]
  tags                        = { Environment = "test" }
  db_credentials_secret_arn   = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:a2t-mrv/db-credentials"
  db_credentials_secret_name  = "a2t-mrv/db-credentials"
  secret_key_base_secret_arn  = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:a2t-mrv/secret-key-base"
  secret_key_base_secret_name = "a2t-mrv/secret-key-base"
  cognito_client_secret_arn   = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:a2t-mrv/cognito-client"
  cognito_user_pool_arn       = "arn:aws:cognito-idp:eu-west-1:123456789012:userpool/eu-west-1_test"
  storage_bucket_name         = "a2t-mrv-crcf-test-bucket"
}

run "security_group_has_three_ingress_rules" {
  command = plan

  assert {
    condition     = length(aws_security_group.main.ingress) == 3
    error_message = "Security group must have exactly 3 ingress rules (SSH, HTTP, HTTPS)"
  }
}

run "security_group_allows_ssh_22" {
  command = plan

  assert {
    condition = anytrue([
      for rule in aws_security_group.main.ingress : rule.from_port == 22 && rule.to_port == 22 && rule.protocol == "tcp"
    ])
    error_message = "Security group must allow TCP port 22 (SSH)"
  }
}

run "security_group_allows_http_80" {
  command = plan

  assert {
    condition = anytrue([
      for rule in aws_security_group.main.ingress : rule.from_port == 80 && rule.to_port == 80 && rule.protocol == "tcp"
    ])
    error_message = "Security group must allow TCP port 80 (HTTP)"
  }
}

run "security_group_allows_https_443" {
  command = plan

  assert {
    condition = anytrue([
      for rule in aws_security_group.main.ingress : rule.from_port == 443 && rule.to_port == 443 && rule.protocol == "tcp"
    ])
    error_message = "Security group must allow TCP port 443 (HTTPS)"
  }
}


run "eip_bound_to_instance" {
  command = plan

  override_resource {
    target          = aws_instance.main
    override_during = plan
    values = {
      id = "i-0123456789abcdef0"
    }
  }

  assert {
    condition     = aws_eip.main.instance == aws_instance.main.id
    error_message = "Elastic IP must be bound to aws_instance.main"
  }
}

run "iam_role_policy_bound_to_ec2_role" {
  command = plan

  override_resource {
    target          = aws_iam_role.ec2
    override_during = plan
    values          = { id = "a2t-mrv-ec2", name = "a2t-mrv-ec2" }
  }

  assert {
    condition     = aws_iam_role_policy.ec2.role == "a2t-mrv-ec2"
    error_message = "IAM inline policy must be attached to the EC2 role"
  }
}

run "instance_profile_references_ec2_role" {
  command = plan

  override_resource {
    target          = aws_iam_role.ec2
    override_during = plan
    values          = { name = "a2t-mrv-ec2" }
  }

  assert {
    condition     = aws_iam_instance_profile.ec2.role == "a2t-mrv-ec2"
    error_message = "Instance profile must reference the EC2 IAM role by name"
  }
}

run "instance_has_codedeploy_tag" {
  command = plan

  assert {
    condition     = lookup(aws_instance.main.tags, "CodeDeployApp", "") == "livedata"
    error_message = "EC2 instance must have tag CodeDeployApp=livedata for CodeDeploy deployment group targeting"
  }
}

run "instance_profile_attached" {
  command = plan

  override_resource {
    target          = aws_iam_instance_profile.ec2
    override_during = plan
    values          = { name = "a2t-mrv-ec2" }
  }

  assert {
    condition     = aws_instance.main.iam_instance_profile == "a2t-mrv-ec2"
    error_message = "EC2 instance must have the IAM instance profile attached"
  }
}

run "output_exposes_role_arn" {
  command = plan

  override_resource {
    target          = aws_iam_role.ec2
    override_during = plan
    values          = { arn = "arn:aws:iam::123456789012:role/a2t-mrv-ec2" }
  }

  assert {
    condition     = output.instance_role_arn == "arn:aws:iam::123456789012:role/a2t-mrv-ec2"
    error_message = "instance_role_arn output must equal the EC2 role ARN"
  }
}
