output "public_ip" {
  description = "Elastic IP address of the production VM."
  value       = module.infra.public_ip
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = module.infra.instance_id
}

output "rds_endpoint" {
  description = "RDS instance endpoint (host:port)."
  value       = module.rds.db_endpoint
}

output "db_credentials_secret_arn" {
  description = "Secrets Manager ARN of the DB credentials secret (username, password, host, port, dbname)."
  value       = module.rds.db_credentials_secret_arn
}

output "secret_key_base_secret_arn" {
  description = "Secrets Manager ARN of the Phoenix SECRET_KEY_BASE."
  value       = module.rds.secret_key_base_secret_arn
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID."
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_endpoint" {
  description = "OIDC issuer URL for the Cognito User Pool."
  value       = module.cognito.user_pool_endpoint
}

output "cognito_app_client_id" {
  description = "Cognito app client ID."
  value       = module.cognito.app_client_id
}

output "cognito_client_secret_arn" {
  description = "Secrets Manager ARN for the Cognito app client credentials."
  value       = module.cognito.client_secret_arn
}

output "storage_bucket_id" {
  description = "S3 bucket name for CRCF retention tiering."
  value       = module.storage.bucket_id
}

output "storage_bucket_arn" {
  description = "ARN of the CRCF retention S3 bucket."
  value       = module.storage.bucket_arn
}

output "instance_role_arn" {
  description = "ARN of the EC2 IAM role. Used by the S3 bucket policy and CodeDeploy deployment group (#148)."
  value       = module.infra.instance_role_arn
}

output "codedeploy_revisions_bucket_name" {
  description = "S3 bucket name for CodeDeploy revision zips."
  value       = aws_s3_bucket.codedeploy_revisions.bucket
}

output "codedeploy_app_name" {
  description = "CodeDeploy application name."
  value       = aws_codedeploy_app.livedata.name
}

output "codedeploy_deployment_group_name" {
  description = "CodeDeploy deployment group name."
  value       = aws_codedeploy_deployment_group.livedata.deployment_group_name
}
