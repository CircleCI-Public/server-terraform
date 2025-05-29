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
  allow_ssh                     = var.allow_ssh
  public_ip                     = var.server_public_ip
  random_string_suffix          = random_string.key_suffix.result
  launch_template_version       = var.launch_template_version
  machine_image_owners          = var.machine_image_owners
  machine_image_names           = var.machine_image_names
  server_nlb_arn                = aws_lb.internal_nlb[0].arn
  log_level                     = var.log_level
}

# Create the Nomad Server Internal NLB
resource "aws_lb" "internal_nlb" {

  count = var.deploy_nomad_server_instances ? 1 : 0

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