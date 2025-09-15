module "server" {
  source = "./modules/nomad-server-aws"

  count = var.deploy_nomad_server_instances ? 1 : 0

  basename                      = var.basename
  vpc_id                        = var.vpc_id
  subnets                       = local.subnet_ids
  aws_region                    = var.aws_region
  nomad_server_hostname         = var.nomad_server_hostname
  tls_cert                      = module.nomad_tls.nomad_server_cert
  tls_key                       = module.nomad_tls.nomad_server_key
  tls_ca                        = module.nomad_tls.nomad_tls_ca
  min_size                      = 3
  max_size                      = var.max_server_instances
  desired_capacity              = var.desired_server_instances
  server_retry_join             = local.server_retry_join
  tag_key_for_discover          = local.tag_key_for_discover
  tag_value_for_discover        = local.tag_value_for_discover
  disk_size_gb                  = var.server_disk_size_gb
  launch_template_instance_type = var.server_machine_type
  tags                          = var.instance_tags
  ssh_key                       = var.ssh_key
  public_ip                     = var.server_public_ip
  random_string_suffix          = random_string.key_suffix.result
  launch_template_version       = var.launch_template_version
  machine_image_owners          = var.machine_image_owners
  machine_image_names           = var.machine_image_names
  server_nlb_arn                = aws_lb.internal_nlb[0].arn
  log_level                     = var.log_level
  security_group_id             = aws_security_group.nomad_server_sg[0].id
}


# Nomad Server Security Group
resource "aws_security_group" "nomad_server_sg" {
  count = var.deploy_nomad_server_instances ? 1 : 0

  name        = "${var.basename}-circleci-nomad-server-sg"
  description = "Security Group for Nomad Server NLB and Instances"
  vpc_id      = var.vpc_id
  tags = merge(
    local.tags,
    {
      "Name" = "${var.basename}-circleci-nomad-server-sg"
    },
  )
}

resource "aws_security_group_rule" "allow-nomad-server-communication-ipv4" {
  count = var.deploy_nomad_server_instances ? 1 : 0

  type                     = "ingress"
  security_group_id        = aws_security_group.nomad_server_sg[0].id
  source_security_group_id = aws_security_group.nomad_sg.id
  from_port                = 4646
  to_port                  = 4648
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "allow-nomad-server-communication-vpc" {
  count = var.deploy_nomad_server_instances ? 1 : 0

  type              = "ingress"
  security_group_id = aws_security_group.nomad_server_sg[0].id
  cidr_blocks       = [data.aws_vpc.nomad.cidr_block]
  from_port         = 4646
  to_port           = 4648
  protocol          = "tcp"
}

resource "aws_security_group_rule" "allow-all-egress-ipv4" {
  count = var.deploy_nomad_server_instances ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"] # tfsec:ignore:aws-vpc-no-public-egress-sgr
  security_group_id = aws_security_group.nomad_server_sg[0].id
}

resource "aws_security_group_rule" "allow-ssh-ipv4" {
  count = var.deploy_nomad_server_instances && var.allow_ssh ? 1 : 0

  type              = "ingress"
  security_group_id = aws_security_group.nomad_server_sg[0].id
  cidr_blocks       = var.allowed_ips_circleci_server_nomad_access # tfsec:ignore:aws-vpc-no-public-ingress-sgr
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
}

# Create the Nomad Server Internal NLB
resource "aws_lb" "internal_nlb" {

  count = var.deploy_nomad_server_instances ? 1 : 0

  name               = "${var.basename}-circleci-nomad-server-nlb"
  internal           = true
  load_balancer_type = "network"

  security_groups = [aws_security_group.nomad_server_sg[0].id]

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