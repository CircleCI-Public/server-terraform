data "aws_iam_policy_document" "ec2_policy" {
  statement {
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "describe_ec2_policy" {
  count = var.nomad_server_enabled ? 1 : 0

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

// Create the role if var.role_name is null and nomad server is enabled 
resource "aws_iam_role" "nomad_instance_role" {
  count = var.nomad_server_enabled && var.role_name != null ? 0 : 1

  name               = "${var.basename}-circleci-nomad-clients-instance-role"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2_policy.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "attach_policy_to_role" {
  count = var.nomad_server_enabled && var.role_name != null ? 0 : 1

  role       = aws_iam_role.nomad_instance_role[0].name
  policy_arn = aws_iam_policy.describe_ec2_policy[0].arn
}

// Attach the policy to the role if var.role_name is not null
data "aws_iam_role" "existing_nomad_role" {
  count = var.nomad_server_enabled && var.role_name != null ? 1 : 0
  name  = var.role_name
}

resource "aws_iam_role_policy_attachment" "attach_policy_to_existing_role" {
  count = var.nomad_server_enabled && var.role_name != null ? 1 : 0

  role       = var.role_name
  policy_arn = aws_iam_policy.describe_ec2_policy[0].arn
}


output "update_nomad_profile_role" {
  value = var.nomad_server_enabled && var.role_name != null ? templatefile(
    "${path.module}/template/nomad-role.txt",
    {
      role = var.role_name
    }
  ) : ""
}