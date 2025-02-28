terraform {
 required_providers {
   aws = {
     source  = "hashicorp/aws"
     version = "~> 5"
   }
   cloudinit = {
      source = "hashicorp/cloudinit"
      version = "2.3.5"
   }
 }
}

provider "aws" {
  region     = var.aws_region
}