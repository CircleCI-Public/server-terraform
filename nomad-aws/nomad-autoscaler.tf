# Only create a nomad aws user if nomad_auto_scaler = true
data "template_file" "nomad_asg_policy" {
  count = var.nomad_auto_scaler ? 1 : 0

  template = file("${path.module}/template/nomad_asg_policy.tpl")

  vars = {
    "ASG_ARN" = aws_autoscaling_group.clients_asg.arn
  }
}

resource "aws_iam_user" "nomad_asg_user" {
  count = var.nomad_auto_scaler ? 1 : 0

  name = "${var.basename}-nomad-asg-user"
}

resource "aws_iam_access_key" "nomad_asg_user" {
  count = var.nomad_auto_scaler ? 1 : 0

  user = aws_iam_user.nomad_asg_user[0].name
}

resource "aws_iam_user_policy" "nomad_asg_user" {
  count = var.nomad_auto_scaler ? 1 : 0

  name   = "${var.basename}-nomad-asg-user-policy"
  user   = aws_iam_user.nomad_asg_user[0].name
  policy = data.template_file.nomad_asg_policy[0].rendered
}
