locals {
  subnet_ids = var.subnet != "" ? [var.subnet] : var.subnets
  tags       = merge(var.tags, { "type" = "nomad-server" })
}

data "aws_ami" "ubuntu_focal" {
  most_recent = true
  filter {
    name   = "name"
    values = var.machine_image_names
  }
  owners = var.machine_image_owners
}


resource "aws_key_pair" "ssh_key" {
  count      = var.ssh_key != null ? 1 : 0
  key_name   = "${var.basename}-circleci-server-nomad-server-ssh-key-${var.random_string_suffix}"
  public_key = var.ssh_key
}

resource "aws_launch_template" "nomad-servers" {
  name_prefix            = "${var.basename}-nomad-servers-"
  image_id               = data.aws_ami.ubuntu_focal.id
  instance_type          = var.launch_template_instance_type
  tags                   = local.tags
  user_data              = data.cloudinit_config.nomad_server_user_data.rendered
  vpc_security_group_ids = [aws_security_group.nomad_server_sg.id]
  update_default_version = true
  key_name               = var.ssh_key != null ? aws_key_pair.ssh_key[0].id : null
  metadata_options {
    http_tokens = var.enable_imdsv2
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.nomad_instance_profile.name
  }
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = var.disk_size_gb
    }
  }
}

resource "aws_autoscaling_group" "autoscale" {
  name                      = "${var.basename}_circleci_nomad_servers_asg"
  health_check_grace_period = 300
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  min_size                  = var.min_size
  health_check_type         = "EC2"
  termination_policies      = ["OldestInstance"]

  target_group_arns = [aws_lb_target_group.target_group.arn]

  launch_template {
    id      = aws_launch_template.nomad-servers.id
    version = var.launch_template_version
  }
  vpc_zone_identifier = local.subnet_ids
  tag {
    key                 = "Name"
    value               = "${var.basename}-nomad-server"
    propagate_at_launch = true
  }
  tag {
    key                 = var.tag_key_for_discover
    value               = var.tag_value_for_discover
    propagate_at_launch = true
  }
}

data "cloudinit_config" "nomad_server_user_data" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "nomad-server-startup.sh.tpl"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/nomad-server-startup.sh.tpl",
      {
        tls_cert          = var.tls_cert
        tls_key           = var.tls_key
        tls_ca            = var.tls_ca
        bootstrap_expect  = var.desired_capacity
        server_retry_join = var.server_retry_join
      }
    )
  }

}

resource "aws_security_group" "nomad_server_sg" {
  name        = "${var.basename}_nomad_server_sg"
  description = "SG for Nomad Server ASG"
  vpc_id      = var.vpc_id
  tags = merge(
    local.tags,
    {
      "Name" = "${var.basename}_nomad_server_sg"
    },
  )
}

resource "aws_vpc_security_group_ingress_rule" "allow-nomad-server-communication-ipv4" {
  security_group_id = aws_security_group.nomad_server_sg.id
  cidr_ipv4         = data.aws_vpc.nomad.cidr_block
  from_port         = 4646
  to_port           = 4648
  ip_protocol       = "tcp"
}

resource "aws_security_group_rule" "allow_all_egress_ipv4" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nomad_server_sg.id
}
