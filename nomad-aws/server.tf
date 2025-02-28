module "server" {
  source = "./modules/nomad-server-aws"

  count = var.nomad_server_enabled ? 1 : 0

  cloud_provider                = "aws"
  vpc_zones_id                  = ["${var.aws_region}a"]
  aws_region                    = var.aws_region
  nomad_server_hostname         = var.nomad_server_hostname
  tls_cert                      = var.enable_mtls ? "" : module.nomad_tls.nomad_server_cert
  tls_key                       = var.enable_mtls ? "" : module.nomad_tls.nomad_server_key
  tls_ca                        = var.enable_mtls ? "" : module.nomad_tls.nomad_tls_ca
  min_size                      = var.min_server_replicas
  max_size                      = var.max_server_replicas
  disk_size_gb                  = var.server_disk_size_gb
  launch_template_instance_type = var.server_machine_type
  tags                          = var.instance_tags
  ssh_key_name                  = var.server_ssh_key
  allow_ssh                     = var.allow_ssh
  public_ip                     = var.server_public_ip
}
