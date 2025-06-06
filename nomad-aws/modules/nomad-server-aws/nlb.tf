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

}

resource "aws_lb_target_group" "target_group_4646" {
  name        = "${var.basename}-circleci-nomad-server-46"
  port        = 4646
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  tags        = local.tags

  health_check {
    path                = "/v1/agent/health?type=server"
    port                = "4646"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "nlb_listener_4646" {
  load_balancer_arn = aws_lb.internal_nlb.arn
  port              = 4646
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_4646.arn
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_4646" {
  autoscaling_group_name = aws_autoscaling_group.autoscale.name
  lb_target_group_arn    = aws_lb_target_group.target_group_4646.arn
}

resource "aws_lb_target_group" "target_group_4647" {
  name        = "${var.basename}-circleci-nomad-server-47"
  port        = 4647
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  tags        = local.tags

  health_check {
    path                = "/v1/agent/health?type=server"
    port                = "4646"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "nlb_listener_4647" {
  load_balancer_arn = aws_lb.internal_nlb.arn
  port              = 4647
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_4647.arn
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_4647" {
  autoscaling_group_name = aws_autoscaling_group.autoscale.name
  lb_target_group_arn    = aws_lb_target_group.target_group_4647.arn
}
resource "aws_lb_target_group" "target_group_4648" {
  name        = "${var.basename}-circleci-nomad-server-48"
  port        = 4648
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  tags        = local.tags

  health_check {
    path                = "/v1/agent/health?type=server"
    port                = "4646"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "nlb_listener_4648" {
  load_balancer_arn = aws_lb.internal_nlb.arn
  port              = 4648
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group_4648.arn
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_4648" {
  autoscaling_group_name = aws_autoscaling_group.autoscale.name
  lb_target_group_arn    = aws_lb_target_group.target_group_4648.arn
}


resource "aws_vpc_security_group_ingress_rule" "allow-ssh-ipv4" {
  count             = var.allow_ssh ? 1 : 0
  security_group_id = aws_security_group.nomad_server_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
