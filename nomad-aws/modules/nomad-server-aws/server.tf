locals {
  fallback_zone = ["${var.aws_region}a"]
  selected_zones = length(var.vpc_zones_id) > 0 ? var.vpc_zones_id : local.fallback_zone
}

data "aws_ami" "ubuntu_focal" {
  most_recent = true
  filter {
    name   = "name"
    values = var.machine_image_names
  }
  owners = var.machine_image_owners
}

resource "aws_launch_template" "nomad-servers" {
  name_prefix = var.name_prefix_launch_template
  image_id        = data.aws_ami.ubuntu_focal.id
  instance_type   = var.launch_template_instance_type
  tags = var.tags
  user_data = data.cloudinit_config.nomad_server_user_data.rendered
  vpc_security_group_ids = [aws_security_group.nomad_server_sg.id]
  update_default_version = true
  key_name = var.ssh_key_name != null ? var.ssh_key_name : null  
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
  name                  = var.asg_name
  health_check_grace_period = 300
  desired_capacity      = var.desired_capacity
  max_size              = var.max_size
  min_size              = var.min_size
  health_check_type     = "EC2"
  termination_policies  = ["OldestInstance"]

  launch_template {
    id      = aws_launch_template.nomad-servers.id
    version = "$Latest"
  }
  vpc_zone_identifier = [aws_subnet.nomad-server-subnet.id]
  tag {
    key = "Name"
    value = var.tag_key_name_value
    propagate_at_launch = true
  }
  tag {
    key = var.tag_key_for_discover
    value = var.tag_value_for_discover
    propagate_at_launch = true
  }
}

data "cloudinit_config" "nomad_server_user_data" {
  gzip          = true
  base64_encode = true

  part {    
    filename = "nomad-server-startup.sh.tpl"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/nomad-server-startup.sh.tpl",
      {
        tls_cert              = var.tls_cert
        tls_key               = var.tls_key
        tls_ca                = var.tls_ca
        provider              = var.cloud_provider
        tag_key               = var.tag_key_for_discover
        tag_value             = var.tag_value_for_discover
        addr_type             = var.addr_type
        region                = var.aws_region
        bootstrap_expect      = var.desired_capacity
      }
    )
  }
  
}

resource "aws_subnet" "nomad-server-subnet" {
  vpc_id     = aws_vpc.nomad-server-vpc.id
  cidr_block = var.vpc_subnet_range
  availability_zone = "${var.aws_region}a"
  tags = merge(
    var.tags,
    {
      "Name" = var.subnet_name
    },
  )
  map_public_ip_on_launch = var.public_ip != null ? var.public_ip : null  
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.nomad-server-vpc.id
  tags = merge(
    var.tags,
    {
      "Name" = var.internet_gateway_name
    },
  )
}

resource "aws_route_table" "nomad-server-rt" {
  vpc_id = aws_vpc.nomad-server-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = merge(
    var.tags,
    {
      "Name" = var.route_table_name
    },
  )
}

resource "aws_route_table_association" "nomad-server-rt-association" {
  subnet_id = aws_subnet.nomad-server-subnet.id
  route_table_id = aws_route_table.nomad-server-rt.id
}

resource "aws_vpc" "nomad-server-vpc" {
  cidr_block       = var.vpc_cidr_range
  instance_tenancy = "default"
  tags = merge(
    var.tags,
    {
      "Name" = var.vpc_name
    },
  )
}

resource "aws_security_group" "nomad_server_sg" {
  name = "nomad_server_sg"
  description = "SG for Nomad Server ASG"
  vpc_id = aws_vpc.nomad-server-vpc.id
  tags = merge(
    var.tags,
    {
      "Name" = var.sg_name
    },
  )
}

resource "aws_vpc_security_group_ingress_rule" "allow-nomad-server-communication-ipv4" {
  security_group_id = aws_security_group.nomad_server_sg.id
  cidr_ipv4         = var.vpc_cidr_range
  from_port         = 4646
  to_port           = 4648
  ip_protocol       = "tcp"
}

resource "aws_security_group_rule" "allow_all_egress_ipv4" {
  type              = "egress"
  from_port        = 0
  to_port          = 0
  protocol         = "-1"
  cidr_blocks      = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nomad_server_sg.id 
}