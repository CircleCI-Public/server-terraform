module "nomad" {
  source = "./nomad"

  ami_id                  = var.ubuntu_ami[var.aws_region]
  aws_subnet_cidr_block   = module.vpc.vpc_cidr_block
  basename                = var.basename
  enable_mtls             = var.enable_mtls
  nomad_count             = var.nomad_count
  nomad_instance_type     = var.nomad_instance_type
  sg_enabled              = var.sg_enabled
  ssh_allowed_cidr_blocks = var.allowed_cidr_blocks
  ssh_key                 = var.nomad_ssh_key
  vpc_id                  = module.vpc.vpc_id
  vpc_zone_identifier     = module.vpc.public_subnets
}
