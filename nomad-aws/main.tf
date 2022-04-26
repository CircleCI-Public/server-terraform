resource "random_string" "key_suffix" {
  length  = 8
  special = false
}

resource "aws_key_pair" "ssh_key" {
  count      = var.ssh_key != null ? 1 : 0
  key_name   = "${var.basename}-circleci-server-nomad-ssh-key-${random_string.key_suffix.result}"
  public_key = var.ssh_key
}

data "aws_ami" "ubuntu_focal" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  owners = ["099720109477", "513442679011"]
}

module "nomad_tls" {
  source                = "../shared/modules/tls"
  nomad_server_endpoint = var.server_endpoint
  count                 = var.enable_mtls ? 1 : 0
}

locals {
  # Creates the Nomad Security Group(SG) list for the Instances.
  # Will include SSH SG if var.ssh_key is not null.
  nomad_security_groups = compact([
    aws_security_group.nomad_sg.id,
    var.ssh_key != null ? aws_security_group.ssh_sg[0].id : "",
  ])
}

data "cloudinit_config" "nomad_user_data" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = templatefile(
      "${path.module}/template/nomad-startup.sh.tpl",
      {
        nomad_server_endpoint = var.server_endpoint
        client_tls_cert       = var.enable_mtls ? module.nomad_tls[0].nomad_client_cert : ""
        client_tls_key        = var.enable_mtls ? module.nomad_tls[0].nomad_client_key : ""
        tls_ca                = var.enable_mtls ? module.nomad_tls[0].nomad_tls_ca : ""
        blocked_cidrs         = var.blocked_cidrs
        docker_network_cidr   = var.docker_network_cidr
        dns_server            = var.dns_server
      }
    )
  }
}

resource "aws_iam_instance_profile" "nomad_client_profile" {
  count = var.role_name != null ? 1 : 0
  name  = "circleci-nomad-clients-instance-profile"
  role  = var.role_name
}

resource "aws_launch_configuration" "nomad_client_lc" {
  instance_type = var.instance_type
  image_id      = data.aws_ami.ubuntu_focal.id
  key_name      = var.ssh_key != null ? aws_key_pair.ssh_key[0].id : null

  iam_instance_profile = var.role_name != null ? aws_iam_instance_profile.nomad_client_profile[0].name : null

  root_block_device {
    volume_type = var.volume_type
    volume_size = "100"
  }

  security_groups = length(var.security_group_id) != 0 ? var.security_group_id : local.nomad_security_groups

  user_data_base64 = data.cloudinit_config.nomad_user_data.rendered

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "clients_asg" {
  name                 = "${var.basename}_circleci_nomad_clients_asg"
  vpc_zone_identifier  = var.subnet != "" ? [var.subnet] : var.subnets
  launch_configuration = aws_launch_configuration.nomad_client_lc.name
  max_size             = var.max_nodes
  min_size             = var.nomad_auto_scaler ? 1 : 0 # When using nomad-autoscaler, the min nodes can't be less than 1. For more info: https://github.com/hashicorp/nomad-autoscaler/issues/530
  desired_capacity     = var.nodes
  force_delete         = true

  tag {
    key                 = "Name"
    value               = "${var.basename}-nomad-client"
    propagate_at_launch = "true"
  }

  dynamic "tag" {
    for_each = var.instance_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
