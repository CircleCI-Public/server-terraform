terraform {
  required_providers {
    aws = {
      version = ">=3.0"
      source  = "hashicorp/aws"
    }
    cloudinit = {
      version = ">=2.0"
      source  = "hashicorp/cloudinit"
    }
  }
}
