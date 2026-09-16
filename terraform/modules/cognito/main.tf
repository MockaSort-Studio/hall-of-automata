
# ── User Pool ─────────────────────────────────────────────────────────────────
resource "aws_cognito_user_pool" "main" {
  name = "${var.app_name}-user-pool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = false
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = var.tags
}

# ── Hosted UI domain ──────────────────────────────────────────────────────────
# Retained intentionally: removing a Cognito domain triggers an immediate
# deletion with no grace period, which would break any bookmarked hosted-UI
# URLs. OAuth flows are not used by the app client, but the domain is kept to
# avoid an irreversible disruptive change.
resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.domain_prefix
  user_pool_id = aws_cognito_user_pool.main.id
}

# ── App client (confidential, USER_PASSWORD_AUTH / REFRESH_TOKEN_AUTH) ────────
resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.app_name}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = true

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 1

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

# ── Client secret in Secrets Manager ─────────────────────────────────────────
# Stores client_id alongside the secret so the app fetches both in one call.
resource "aws_secretsmanager_secret" "cognito_client" {
  name        = "${var.app_name}/cognito/client-secret"
  description = "Cognito app client credentials for ${var.app_name}"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "cognito_client" {
  secret_id = aws_secretsmanager_secret.cognito_client.id
  secret_string = jsonencode({
    client_id     = aws_cognito_user_pool_client.main.id
    client_secret = aws_cognito_user_pool_client.main.client_secret
  })
}

# ── SSM parameters (non-secret config read by the app at first auth) ──────────
resource "aws_ssm_parameter" "cognito_region" {
  name  = "/${var.app_name}/cognito/region"
  type  = "String"
  value = data.aws_region.current.name
  tags  = var.tags
}

resource "aws_ssm_parameter" "cognito_user_pool_id" {
  name  = "/${var.app_name}/cognito/user-pool-id"
  type  = "String"
  value = aws_cognito_user_pool.main.id
  tags  = var.tags
}

# ── Admin group ───────────────────────────────────────────────────────────────
# @req: KR 4.1
resource "aws_cognito_user_pool_group" "admins" {
  name         = "admins"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Users with access to admin routes"
}

# ── Admin test user ───────────────────────────────────────────────────────────
resource "aws_cognito_user" "admin_test" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = var.admin_test_email

  attributes = {
    email          = var.admin_test_email
    email_verified = "true"
  }

  message_action = "SUPPRESS"
}

resource "aws_cognito_user_in_group" "admin_test" {
  user_pool_id = aws_cognito_user_pool.main.id
  group_name   = aws_cognito_user_pool_group.admins.name
  username     = aws_cognito_user.admin_test.username
}
