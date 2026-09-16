variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-west-1"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Name of the EC2 key pair to attach to the instance for SSH access."
  type        = string
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed inbound SSH. Restrict to known IPs in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    Project   = "a2t-mrv"
    ManagedBy = "terraform"
  }
}

variable "db_name" {
  description = "Name of the initial database created on the RDS instance."
  type        = string
  default     = "livedata"
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "livedata"
}

variable "backup_retention_days" {
  description = "Days to retain automated RDS backups (1-35)."
  type        = number
  default     = 7
}

variable "phx_host" {
  description = "Public hostname for the Phoenix app (bare domain, no scheme). Used by Caddy for TLS and by the app for URL generation."
  type        = string
  default     = "dev.mrv.airtotree.com"
}

variable "cognito_app_name" {
  description = "Application name prefix for Cognito resource names."
  type        = string
  default     = "a2t-mrv"
}

variable "cognito_domain_prefix" {
  description = "Globally unique prefix for the Cognito hosted UI domain."
  type        = string
  default     = "a2t-mrv"
}

variable "codedeploy_revisions_bucket_name" {
  description = "Globally unique S3 bucket name for CodeDeploy revision zips."
  type        = string
  default     = "a2t-mrv-codedeploy-revisions-559744161469"
}

variable "storage_days_to_warm" {
  description = "Days before objects transition from Standard to Standard-IA (warm tier)."
  type        = number
  default     = 30
}

variable "storage_days_to_cold" {
  description = "Days before objects transition from Standard-IA to Glacier (cold tier)."
  type        = number
  default     = 90
}

variable "admin_test_email" {
  description = "Email address for the admin test user in the Cognito user pool."
  type        = string
  default     = "admin@mock.local"
}
