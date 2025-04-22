data "aws_vpc" "nomad" {
  id = var.vpc_id
}

# Create the Internal NLB
resource "aws_lb" "internal_nlb" {
  name               = "${var.basename}-circleci-nomad-server-nlb"
  internal           = true
  load_balancer_type = "network"

  dynamic "subnet_mapping" {
    for_each = local.subnet_ids
    content {
      subnet_id = subnet_mapping.value
    }
  }
  tags = merge(
    local.tags,
    {
      "Name" = "${var.basename}-circleci-nomad-server-nlb"
    },
  )

  depends_on = [aws_autoscaling_group.autoscale]
}

resource "aws_lb_target_group" "target_group" {
  name     = "${var.basename}-circleci-nomad-server-tg"
  port     = 4647
  protocol = "TCP"
  vpc_id   = var.vpc_id
  tags     = local.tags
}

resource "aws_lb_listener" "nlb_listener_4646" {
  load_balancer_arn = aws_lb.internal_nlb.arn
  port              = 4646
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_lb_listener" "nlb_listener_4647" {
  load_balancer_arn = aws_lb.internal_nlb.arn
  port              = 4647
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_lb_listener" "nlb_listener_4648" {
  load_balancer_arn = aws_lb.internal_nlb.arn
  port              = 4648
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow-ssh-ipv4" {
  count             = var.allow_ssh ? 1 : 0
  security_group_id = aws_security_group.nomad_server_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
