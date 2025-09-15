resource "random_string" "key_suffix" {
  length  = 8
  special = false
}

locals {

  subnet_ids                 = var.subnet != "" ? [var.subnet] : var.subnets
  tag_key_for_discover       = "identifier"
  tag_value_for_discover     = "${var.basename}-circleci-nomad-server-instances-${random_string.key_suffix.result}"
  server_retry_join          = "provider=aws tag_key=${local.tag_key_for_discover} tag_value=${local.tag_value_for_discover} addr_type=${var.addr_type} region=${var.aws_region}"
  nomad_client_instance_role = var.role_name != null ? var.role_name : (var.deploy_nomad_server_instances ? aws_iam_role.nomad_instance_role[0].name : null)

  instance_tags = merge(var.instance_tags, { "type" = "circleci-nomad-client" })
}

resource "aws_key_pair" "ssh_key" {
  count      = var.ssh_key != null ? 1 : 0
  key_name   = "${var.basename}-circleci-server-nomad-client-ssh-key-${random_string.key_suffix.result}"
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

data "aws_vpc" "nomad" {
  id = var.vpc_id
}

module "nomad_tls" {
  source                = "../shared/modules/tls"
  nomad_server_hostname = var.deploy_nomad_server_instances ? "nomad-server.${var.nomad_server_hostname}" : var.nomad_server_hostname
  nomad_server_port     = var.nomad_server_port
}

data "cloudinit_config" "nomad_user_data" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = templatefile(
      "${path.module}/template/nomad-startup.sh.tpl",
      {
        nomad_version       = var.nomad_version
        client_tls_cert     = module.nomad_tls.nomad_client_cert
        client_tls_key      = module.nomad_tls.nomad_client_key
        tls_ca              = module.nomad_tls.nomad_tls_ca
        blocked_cidrs       = var.blocked_cidrs
        docker_network_cidr = var.docker_network_cidr
        dns_server          = var.dns_server
        server_retry_join   = var.deploy_nomad_server_instances ? local.server_retry_join : var.nomad_server_hostname
        log_level           = var.log_level
      }
    )
  }
}

resource "aws_iam_instance_profile" "nomad_client_profile" {
  count = local.nomad_client_instance_role != null ? 1 : 0
  name  = "${var.basename}-circleci-nomad-clients-instance-profile"
  role  = local.nomad_client_instance_role
}

#tfsec:ignore:aws-ec2-enforce-launch-config-http-token-imds
resource "aws_launch_template" "nomad_clients" {
  name_prefix   = "${var.basename}-nomad-clients-"
  instance_type = var.instance_type
  image_id      = data.aws_ami.ubuntu_focal.id
  key_name      = var.ssh_key != null ? aws_key_pair.ssh_key[0].id : null

  network_interfaces {
    associate_public_ip_address = var.client_public_ip
    security_groups             = length(var.security_group_id) != 0 ? var.security_group_id : [aws_security_group.nomad_sg.id]
  }

  metadata_options {
    http_tokens = var.enable_imdsv2
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type = var.volume_type
      volume_size = var.disk_size_gb
    }
  }

  dynamic "iam_instance_profile" {
    for_each = local.nomad_client_instance_role != null ? [1] : []
    content {
      arn = aws_iam_instance_profile.nomad_client_profile[0].arn
    }
  }

  user_data = data.cloudinit_config.nomad_user_data.rendered

  dynamic "tag_specifications" {
    for_each = ["instance", "volume"]
    content {
      resource_type = tag_specifications.value
      tags          = local.instance_tags
    }
  }
}

resource "aws_autoscaling_group" "clients_asg" {
  name                = "${var.basename}-circleci-nomad-clients-asg"
  vpc_zone_identifier = local.subnet_ids
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
    for_each = local.instance_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
