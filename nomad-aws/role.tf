data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "ec2_policy" {
  statement {
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
  statement {
    actions = ["autoscaling:SetInstanceHealth"]
    resources = [
      "arn:${data.aws_partition.current.partition}:autoscaling:${var.aws_region}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.basename}-circleci-nomad-clients-asg"
    ]
  }
}

resource "aws_iam_policy" "describe_ec2_policy" {
  name        = "${var.basename}-circleci-nomad-clients-role-policy"
  description = "Policy to allow ec2:DescribeInstances"
  policy      = data.aws_iam_policy_document.ec2_policy.json
  tags        = local.tags
}


data "aws_iam_policy_document" "assume_ec2_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

// Create the role only if var.role_name is null
resource "aws_iam_role" "nomad_instance_role" {
  count = var.role_name == null ? 1 : 0

  name               = "${var.basename}-circleci-nomad-clients-instance-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2_policy.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "attach_policy_to_role" {
  count = var.role_name == null ? 1 : 0

  role       = aws_iam_role.nomad_instance_role[0].name
  policy_arn = aws_iam_policy.describe_ec2_policy.arn
}

// Attach the policy to the role if var.role_name is not null
data "aws_iam_role" "existing_nomad_role" {
  count = var.role_name != null ? 1 : 0
  name  = var.role_name
}

resource "aws_iam_role_policy_attachment" "attach_policy_to_existing_role" {
  count = var.role_name != null ? 1 : 0

  role       = var.role_name
  policy_arn = aws_iam_policy.describe_ec2_policy.arn
}


output "update_nomad_profile_role" {
  value = var.role_name != null ? templatefile(
    "${path.module}/template/nomad-role.txt",
    {
      role = var.role_name
    }
  ) : ""
}