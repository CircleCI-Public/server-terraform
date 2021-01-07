resource "aws_s3_bucket" "data_bucket" {
  bucket        = "${var.basename}-data"
  force_destroy = var.force_destroy

  tags = {
    Terraform     = "true"
    Environment   = "circleci"
    circleci      = true
    Name          = "${var.basename}-circleci-data"
    force_destroy = var.force_destroy
  }
}
