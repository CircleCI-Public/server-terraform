locals {
  ssh_enabled = var.ssh_key != null
}

resource "aws_key_pair" "ssh_key" {
  count      = local.ssh_enabled ? 1 : 0
  key_name   = "${var.basename}-circleci-nomad-ssh-key"
  public_key = var.ssh_key
  tags = {
    Terraform = "true"
    circleci  = "true"
  }
}

module "nomad_tls" {
  source   = "../../shared/modules/tls"
  basename = var.basename
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 3.0"

  name = "${var.basename}-circleci-nomad_asg"

  # Launch configuration
  lc_name = "${var.basename}-circleci-nomad_lc"

  image_id      = var.ami_id
  instance_type = var.nomad_instance_type
  key_name      = local.ssh_enabled ? aws_key_pair.ssh_key[0].id : null
  security_groups = compact([
    aws_security_group.nomad_sg[0].id,
    local.ssh_enabled ? aws_security_group.ssh_sg[0].id : "",
  ])

  root_block_device = [
    {
      volume_size = "500"
      volume_type = "gp2"
    },
  ]

  # User data
  user_data_base64 = base64encode(templatefile(
    "${path.module}/../../shared/nomad-scripts/nomad-startup.sh.tpl",
    {
      basename        = var.basename
      cloud_provider  = "AWS"
      client_tls_cert = module.nomad_tls.nomad_client_cert
      client_tls_key  = module.nomad_tls.nomad_client_key
      tls_ca          = module.nomad_tls.nomad_tls_ca
    }
  ))

  # Auto scaling group
  asg_name                  = "${var.basename}-circleci-nomad_asg"
  vpc_zone_identifier       = var.vpc_zone_identifier
  health_check_type         = "EC2"
  min_size                  = var.nomad_count
  max_size                  = var.nomad_count
  desired_capacity          = var.nomad_count
  wait_for_capacity_timeout = 0 # skip all Capacity Waiting behavior

  tags = [
    {
      key                 = "Terraform"
      value               = "true"
      propagate_at_launch = true
    },
    {
      key                 = "circleci"
      value               = "true"
      propagate_at_launch = true
    },
    {
      key                 = "Environment"
      value               = "circleci"
      propagate_at_launch = true
    }
  ]
}

resource "aws_security_group" "nomad_sg" {
  count       = var.sg_enabled
  name        = "${var.basename}-circleci-nomad_sg"
  description = "SG for CircleCI Server nomad server/client"
  vpc_id      = var.vpc_id

  # For nomad servers and clients to communicate
  ingress {
    from_port   = 4646
    to_port     = 4648
    protocol    = "tcp"
    cidr_blocks = [var.aws_subnet_cidr_block]
  }

  # For SSHing into a job as an end user (not operators)
  ingress {
    from_port   = 64535
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# We are allowing port 22 for operators
# to debug nomad clients
resource "aws_security_group" "ssh_sg" {
  count       = local.ssh_enabled ? 1 : 0
  name        = "${var.basename}-circleci-nomad_ssh"
  description = "SG for CircleCI Server nomad SSH access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# OUTPUTS
output "nomad_server_cert" {
  value = module.nomad_tls.nomad_server_cert
}

output "nomad_server_key" {
  value = module.nomad_tls.nomad_server_key
}

output "nomad_tls_ca" {
  value = module.nomad_tls.nomad_tls_ca
}
