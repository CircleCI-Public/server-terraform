resource "aws_s3_bucket" "data_bucket" {
  bucket        = "${var.basename}-data"
  force_destroy = var.force_destroy

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3600
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Terraform     = "true"
    Environment   = "circleci"
    circleci      = true
    Name          = "${var.basename}-circleci-data"
    force_destroy = var.force_destroy
  }
}
