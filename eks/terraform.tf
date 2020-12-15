provider "aws" {
  version = "~> 3.0.0"
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null
}
