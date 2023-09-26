locals {
  nomad_server_hostname_and_port = "${var.nomad_server_hostname}:${var.nomad_server_port}"
}

resource "random_string" "key_suffix" {
  length  = 8
  special = false
}

resource "aws_key_pair" "ssh_key" {
  count      = var.ssh_key != null ? 1 : 0
  key_name   = "circleci-server-nomad-ssh-key-${random_string.key_suffix.result}"
  public_key = var.ssh_key
}

data "aws_ami" "ubuntu_focal" {
  most_recent = true

  filter {
    name   = "name"
    values = var.machine_image_names
  }

  owners = var.machine_image_owners
}

module "nomad_tls" {
  source                = "../shared/modules/tls"
  nomad_server_hostname = var.nomad_server_hostname
  nomad_server_port     = var.nomad_server_port
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
        patched_nomad_version = var.patched_nomad_version
        nomad_server_endpoint = local.nomad_server_hostname_and_port
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

resource "aws_launch_template" "nomad_clients" {
  name_prefix   = "${var.basename}-nomad-clients-"
  instance_type = var.instance_type
  image_id      = data.aws_ami.ubuntu_focal.id
  key_name      = var.ssh_key != null ? aws_key_pair.ssh_key[0].id : null

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type = var.volume_type
      volume_size = var.disk_size_gb
    }
  }

  dynamic "iam_instance_profile" {
    for_each = var.role_name != null ? [1] : []
    content {
      arn = aws_iam_instance_profile.nomad_client_profile[0].arn
    }
  }

  vpc_security_group_ids = length(var.security_group_id) != 0 ? var.security_group_id : local.nomad_security_groups
  user_data              = data.cloudinit_config.nomad_user_data.rendered

  dynamic "tag_specifications" {
    for_each = ["instance", "volume"]
    content {
      resource_type = tag_specifications.value
      tags          = var.instance_tags
    }
  }
}

resource "aws_autoscaling_group" "clients_asg" {
  name                = "${var.basename}_circleci_nomad_clients_asg"
  vpc_zone_identifier = var.subnet != "" ? [var.subnet] : var.subnets
  max_size            = var.max_nodes
  min_size            = var.nomad_auto_scaler ? 1 : 0 # When using nomad-autoscaler, the min nodes can't be less than 1. For more info: https://github.com/hashicorp/nomad-autoscaler/issues/530
  desired_capacity    = var.nodes
  force_delete        = true

  launch_template {
    id      = aws_launch_template.nomad_clients.id
    version = var.launch_template_version
  }

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
