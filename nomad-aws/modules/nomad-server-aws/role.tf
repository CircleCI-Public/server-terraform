resource "aws_iam_policy" "describe_ec2_policy" {
  name        = "${var.basename}-circleci-nomad-server-role-policy"
  description = "Policy to allow ec2:DescribeInstances"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ec2:DescribeInstances"
        Resource = "*"
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_role" "nomad_role" {
  name = "${var.basename}-circleci-nomad-server-autoscaler-irsa-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "attach_policy_to_role" {
  role       = aws_iam_role.nomad_role.name
  policy_arn = aws_iam_policy.describe_ec2_policy.arn
}

resource "aws_iam_instance_profile" "nomad_instance_profile" {
  name = "${var.basename}-circleci-nomad-server-instance-profile"
  role = aws_iam_role.nomad_role.name
}
