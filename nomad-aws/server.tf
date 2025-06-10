module "server" {
  source = "./modules/nomad-server-aws"

  count = var.deploy_nomad_server_instances ? 1 : 0

  basename                      = var.basename
  vpc_id                        = var.vpc_id
  subnet                        = var.subnet
  subnets                       = var.subnets
  aws_region                    = var.aws_region
  nomad_server_hostname         = var.nomad_server_hostname
  tls_cert                      = var.enable_mtls ? module.nomad_tls[0].nomad_server_cert : ""
  tls_key                       = var.enable_mtls ? module.nomad_tls[0].nomad_server_key : ""
  tls_ca                        = var.enable_mtls ? module.nomad_tls[0].nomad_tls_ca : ""
  min_size                      = 3
  max_size                      = var.max_server_instances
  desired_capacity              = var.desired_server_instances
  server_retry_join             = local.server_retry_join
  tag_key_for_discover          = var.tag_key_for_discover
  tag_value_for_discover        = var.tag_value_for_discover
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
}