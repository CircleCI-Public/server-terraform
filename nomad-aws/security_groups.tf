resource "aws_security_group" "nomad_sg" {
  name        = "${var.basename}-nomad_sg"
  description = "Security group that allows external users to SSH into nomad instances for CircleCI Retry with SSH feature"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow CircleCI Retry with SSH Access"
    from_port   = 64535
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips_retry_ssh # tfsec:ignore:aws-vpc-no-public-ingress-sgr
  }

  egress {
    description = "Allow CircleCI Nomad outbound connections"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # tfsec:ignore:aws-vpc-no-public-egress-sgr
  }
}

resource "aws_security_group" "nomad_traffic_sg" {
  name        = "${var.basename}-nomad_traffic_sg"
  description = "Security group that restrict Nomad Client Server communication within VPC CIDR"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow CircleCI Nomad traffic within VPC"
    from_port   = 4646
    to_port     = 4648
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.nomad.cidr_block]
  }

  egress {
    description = "Allow CircleCI Nomad outbound connections"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # tfsec:ignore:aws-vpc-no-public-egress-sgr
  }
}

resource "aws_security_group" "ssh_sg" {
  description = "Security group that permits CircleCI Server to SSH into nomad instances"
  count       = var.ssh_key != null ? 1 : 0
  name        = "${var.basename}-circleci-nomad_ssh"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips_circleci_server_nomad_access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
