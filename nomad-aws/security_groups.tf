resource "aws_security_group" "nomad_sg" {
  name        = "${var.basename}-circleci-nomad-clients-sg"
  description = "CircleCI Nomad Clients Security"
  vpc_id      = var.vpc_id
  tags = merge(
    local.tags,
    {
      "Name" = "${var.basename}-circleci-nomad-clients-sg"
    },
  )
}


resource "aws_security_group_rule" "nomad_outbound_egress" {
  description       = "Allow CircleCI Nomad outbound connections"
  security_group_id = aws_security_group.nomad_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"] # tfsec:ignore:aws-vpc-no-public-egress-sgr
}


resource "aws_security_group_rule" "nomad_retry_ssh_ingress" {
  description       = "Allow CircleCI to run a nomad job with Retry with SSH Access"
  security_group_id = aws_security_group.nomad_sg.id
  type              = "ingress"
  from_port         = 64535
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ips_retry_ssh # tfsec:ignore:aws-vpc-no-public-ingress-sgr
}


resource "aws_security_group_rule" "nomad_traffic_sg" {
  description       = "Allow CircleCI Nomad traffic from/to within VPC"
  security_group_id = aws_security_group.nomad_sg.id
  type              = "ingress"
  from_port         = 4646
  to_port           = 4648
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.nomad.cidr_block]
}


resource "aws_security_group_rule" "nomad_ssh_sg" {
  count             = var.ssh_key != null ? 1 : 0
  description       = "Allow CircleCI Server to SSH into nomad instances"
  security_group_id = aws_security_group.nomad_sg.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ips_circleci_server_nomad_access
}
