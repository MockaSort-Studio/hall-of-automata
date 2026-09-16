variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "eu-north-1"
}

variable "account_id" {
  description = "AWS account ID — used to scope the CI policy ARNs."
  type        = string
}
