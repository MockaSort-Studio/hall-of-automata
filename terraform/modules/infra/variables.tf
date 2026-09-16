variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name for SSH access."
  type        = string
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks permitted inbound on port 22."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
}

variable "db_credentials_secret_arn" {
  description = "Secrets Manager ARN for the DB credentials secret (username, password, host, port, dbname)."
  type        = string
}

variable "db_credentials_secret_name" {
  description = "Secrets Manager name for the DB credentials secret. Written to /etc/livedata/secrets.conf by user_data."
  type        = string
}

variable "secret_key_base_secret_arn" {
  description = "Secrets Manager ARN for the Phoenix SECRET_KEY_BASE."
  type        = string
}

variable "secret_key_base_secret_name" {
  description = "Secrets Manager name for the Phoenix SECRET_KEY_BASE. Written to /etc/livedata/secrets.conf by user_data."
  type        = string
}

variable "cognito_client_secret_arn" {
  description = "Secrets Manager ARN for the Cognito app-client credentials (from the cognito module)."
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool. Grants the EC2 role permission to call InitiateAuth."
  type        = string
}

variable "storage_bucket_name" {
  description = "Name of the CRCF retention S3 bucket. Used to construct the IAM policy ARN without a module output reference."
  type        = string
}
