# Verifies internal wiring of the cognito module without any real AWS calls.
# Requires Terraform >= 1.11.0 (override_during support).

mock_provider "aws" {}

variables {
  app_name         = "a2t-mrv"
  domain_prefix    = "a2t-mrv"
  tags             = { Environment = "test" }
  admin_test_email = "admin@mock.local"
}

run "user_pool_uses_email_as_username" {
  command = plan

  assert {
    condition     = contains(aws_cognito_user_pool.main.username_attributes, "email")
    error_message = "User pool must use email as the username attribute"
  }
}

run "user_pool_verifies_email" {
  command = plan

  assert {
    condition     = contains(aws_cognito_user_pool.main.auto_verified_attributes, "email")
    error_message = "User pool must auto-verify email"
  }
}

run "app_client_allows_user_password_auth" {
  command = plan

  assert {
    condition     = contains(aws_cognito_user_pool_client.main.explicit_auth_flows, "ALLOW_USER_PASSWORD_AUTH")
    error_message = "App client must allow USER_PASSWORD_AUTH so InitiateAuth can be called directly"
  }
}

run "app_client_allows_refresh_token_auth" {
  command = plan

  assert {
    condition     = contains(aws_cognito_user_pool_client.main.explicit_auth_flows, "ALLOW_REFRESH_TOKEN_AUTH")
    error_message = "App client must allow REFRESH_TOKEN_AUTH for token refresh"
  }
}

run "app_client_has_no_srp_auth" {
  command = plan

  assert {
    condition     = !contains(aws_cognito_user_pool_client.main.explicit_auth_flows, "ALLOW_USER_SRP_AUTH")
    error_message = "App client must not enable SRP auth — the app uses USER_PASSWORD_AUTH only"
  }
}

run "app_client_generates_secret" {
  command = plan

  assert {
    condition     = aws_cognito_user_pool_client.main.generate_secret == true
    error_message = "App client must be a confidential client (generate_secret = true)"
  }
}

run "secret_stored_separately_from_infra" {
  command = plan

  assert {
    condition     = strcontains(aws_secretsmanager_secret.cognito_client.name, "cognito")
    error_message = "Secrets Manager secret name must contain 'cognito' to distinguish it from the DB credential secret"
  }
}

run "domain_prefix_matches_var" {
  command = plan

  assert {
    condition     = aws_cognito_user_pool_domain.main.domain == var.domain_prefix
    error_message = "User pool domain prefix must match var.domain_prefix"
  }
}

run "admins_group_exists" {
  command = plan

  assert {
    condition     = aws_cognito_user_pool_group.admins.name == "admins"
    error_message = "admins group must be named 'admins'"
  }
}

run "admin_test_user_assigned_to_admins_group" {
  command = plan

  assert {
    condition     = aws_cognito_user_in_group.admin_test.group_name == aws_cognito_user_pool_group.admins.name
    error_message = "Admin test user must be assigned to the admins group"
  }
}
