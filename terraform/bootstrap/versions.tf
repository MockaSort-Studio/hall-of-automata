terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # No remote backend — this root is applied once by a human with admin credentials.
  # State is local; commit nothing from it.
}

provider "aws" {
  region = var.aws_region
}
