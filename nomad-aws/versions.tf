terraform {
  required_providers {
    aws = {
      version = ">= 5.0"
      source  = "hashicorp/aws"
    }
    cloudinit = {
      version = ">=2.3"
      source  = "hashicorp/cloudinit"
    }
  }
}