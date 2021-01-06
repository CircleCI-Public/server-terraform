terraform {
  required_providers {
    kubernetes = {
      version = "~> 1.11"
    }
    aws = {
      version = "~> 3.3.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null
  assume_role {
    role_arn = var.additional_bastion_role_arn
  }
}
