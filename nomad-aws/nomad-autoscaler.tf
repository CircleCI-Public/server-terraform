# Only create a nomad aws user if oidc_arn is empty map {}
data "template_file" "nomad_asg_policy" {
  template = file("${path.module}/template/nomad_asg_policy.tpl")

  vars = {
    "ASG_ARN" = aws_autoscaling_group.clients_asg.arn
  }
}

resource "aws_iam_user" "nomad_asg_user" {
  count = length(var.enable_irsa) == 0 ? 1 : 0

  name = "${var.basename}-nomad-asg-user"
}

resource "aws_iam_access_key" "nomad_asg_user" {
  count = length(var.enable_irsa) == 0 ? 1 : 0

  user = aws_iam_user.nomad_asg_user[0].name
}

resource "aws_iam_user_policy" "nomad_asg_user" {
  count = length(var.enable_irsa) == 0 ? 1 : 0

  name   = "${var.basename}-nomad-asg-user-policy"
  user   = aws_iam_user.nomad_asg_user[0].name
  policy = data.template_file.nomad_asg_policy.rendered
}


# Only create a nomad aws role if length of oidc_arn > 0
data "template_file" "nomad_role_trust_policy" {
  count = length(var.enable_irsa) > 0 ? 1 : 0

  template                = file("${path.module}/template/nomad_irsa_trust_policy.tpl")
  vars                    = {
    OIDC_PRINCIPAL_ID     = lookup(var.enable_irsa, "oidc_principal_id", "")
    OIDC_EKS_VARIABLE     = lookup(var.enable_irsa, "oidc_eks_variable", "")
    K8S_SERVICE_ACCOUNT   = lookup(var.enable_irsa, "k8s_service_account", "")
  }

}

resource "aws_iam_role" "nomad_role" {
  count = length(var.enable_irsa) > 0 ? 1 : 0

  name                    = "${var.basename}-circleci-nomad-autoscaler-irsa-role"
  assume_role_policy      =   data.template_file.nomad_role_trust_policy[0].rendered

  inline_policy {
                name      = "${var.basename}-circleci-nomad-autoscaler-role-policy"
                policy    = data.template_file.nomad_asg_policy.rendered
  }
  tags                    = local.tags
}