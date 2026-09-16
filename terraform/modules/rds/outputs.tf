output "db_endpoint" {
  description = "RDS instance endpoint (host:port)."
  value       = aws_db_instance.main.endpoint
}

output "db_port" {
  description = "RDS instance port."
  value       = aws_db_instance.main.port
}

output "db_credentials_secret_arn" {
  description = "Secrets Manager ARN for the DB credentials secret (username, password, host, port, dbname)."
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_secret_name" {
  description = "Secrets Manager name for the DB credentials secret."
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "secret_key_base_secret_arn" {
  description = "Secrets Manager ARN of the Phoenix SECRET_KEY_BASE."
  value       = aws_secretsmanager_secret.secret_key_base.arn
}

output "secret_key_base_secret_name" {
  description = "Secrets Manager name of the Phoenix SECRET_KEY_BASE."
  value       = aws_secretsmanager_secret.secret_key_base.name
}
