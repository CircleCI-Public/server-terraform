terraform {
  required_providers {
    aws = {
      version = "~> 5"
      source  = "hashicorp/aws"
    }
    cloudinit = {
      version = ">=2.3"
      source  = "hashicorp/cloudinit"
    }
  }
}