variable "vpc_id" {
  description = "VPC ID in which to place the RDS instance and its security group."
  type        = string
}

variable "db_subnet_ids" {
  description = "List of private subnet IDs (minimum two, in different AZs) for the DB subnet group."
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group ID of the EC2 app instance; allowed inbound on port 5432."
  type        = string
}

variable "db_name" {
  description = "Name of the initial database created on the RDS instance."
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
}

variable "db_password" {
  description = "Master password for the RDS instance. Must not contain URL-reserved characters (: @ / ? #)."
  type        = string
  sensitive   = true
}

variable "backup_retention_days" {
  description = "Number of days to retain automated RDS backups (1–35)."
  type        = number
}

variable "tags" {
  description = "Tags applied to every resource in this module."
  type        = map(string)
}
