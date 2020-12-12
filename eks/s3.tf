data "aws_caller_identity" "current" {}

resource "aws_kms_key" "data_bucket_key" {
  description             = "This key is used to encrypt the data_bucket"
  deletion_window_in_days = 10


# This policy allows the root to manage the keys - needed for terraform to manage the keys and provides the cluster nodes with limited access to keys
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "kms:*"
      ],
      "Principal": { "AWS": [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        ]
      },
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "kms:Decrypt",
        "kms:GenerateDataKey*"
      ],
      "Principal": { "AWS": [
          "${module.eks-cluster.worker_iam_role_arn}"
        ]
      },
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

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
        kms_master_key_id = aws_kms_key.data_bucket_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = {
    Terraform     = "true"
    Environment   = "circleci"
    circleci      = true
    Name          = "${var.basename}-circleci-data"
    force_destroy = true
  }
}


output "user_arn" {
  value = data.aws_caller_identity.current.arn
}

output "cluster_arn" {
  value = module.eks-cluster.cluster_iam_role_arn
}

output "worker_arn" {
  value = module.eks-cluster.worker_iam_role_arn
}

