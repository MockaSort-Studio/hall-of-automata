data "aws_caller_identity" "current" {}

# ── DB password ───────────────────────────────────────────────────────────────
# Generated once; stored in Secrets Manager via the rds module.
# special = false avoids URL-reserved characters (: @ / ? #) in the ecto:// URL.
resource "random_password" "db" {
  length  = 32
  special = false
}

# ── Runtime SSM Parameters ────────────────────────────────────────────────────
# Non-secret runtime config computed at apply time and read by deploy scripts.
# Secrets (DB credentials, secret_key_base) live in Secrets Manager, not here.
resource "aws_ssm_parameter" "cognito_pool_id" {
  name  = "/a2t-mrv/runtime/cognito-user-pool-id"
  type  = "String"
  value = module.cognito.user_pool_id
}

resource "aws_ssm_parameter" "cognito_domain_prefix" {
  name  = "/a2t-mrv/runtime/cognito-domain-prefix"
  type  = "String"
  value = var.cognito_domain_prefix
}

resource "aws_ssm_parameter" "phx_host" {
  name  = "/a2t-mrv/runtime/phx-host"
  type  = "String"
  value = var.phx_host
}

resource "aws_ssm_parameter" "database_ssl_ca_url" {
  name      = "/a2t-mrv/runtime/database-ssl-ca-url"
  type      = "String"
  value     = "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem"
  overwrite = true
}

locals {
  storage_bucket_name = "a2t-mrv-storage-${data.aws_caller_identity.current.account_id}"
}

module "infra" {
  source = "./modules/infra"

  instance_type   = var.instance_type
  key_name        = var.key_name
  ssh_cidr_blocks = var.ssh_cidr_blocks
  tags            = var.tags

  db_credentials_secret_arn   = module.rds.db_credentials_secret_arn
  db_credentials_secret_name  = module.rds.db_credentials_secret_name
  secret_key_base_secret_arn  = module.rds.secret_key_base_secret_arn
  secret_key_base_secret_name = module.rds.secret_key_base_secret_name
  cognito_client_secret_arn   = module.cognito.client_secret_arn
  cognito_user_pool_arn       = module.cognito.user_pool_arn
  storage_bucket_name         = local.storage_bucket_name
}

module "rds" {
  source = "./modules/rds"

  vpc_id                = module.infra.vpc_id
  db_subnet_ids         = module.infra.db_subnet_ids
  app_security_group_id = module.infra.app_security_group_id

  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = random_password.db.result
  backup_retention_days = var.backup_retention_days
  tags                  = var.tags
}

module "cognito" {
  source = "./modules/cognito"

  app_name         = var.cognito_app_name
  domain_prefix    = var.cognito_domain_prefix
  tags             = var.tags
  admin_test_email = var.admin_test_email
}

module "storage" {
  source = "./modules/storage"

  bucket_name           = local.storage_bucket_name
  ec2_instance_role_arn = module.infra.instance_role_arn
  create_bucket_policy  = true
  days_to_warm          = var.storage_days_to_warm
  days_to_cold          = var.storage_days_to_cold
  tags                  = var.tags
}
