terraform {
  required_providers {
    kubernetes = {
      version = "~> 1.11"
    }
    aws        = {
      version = "~> 3.0.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null
}
