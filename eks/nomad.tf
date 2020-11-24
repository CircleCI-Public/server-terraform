module "nomad" {
  source = "./nomad"

  basename                = var.basename
  nomad_instance_type     = var.nomad_instance_type
  ssh_key                 = var.nomad_ssh_key
  ssh_allowed_cidr_blocks = var.allowed_cidr_blocks
  aws_subnet_cidr_block   = var.aws_subnet_cidr_block
  sg_enabled              = var.sg_enabled
  nomad_count             = var.nomad_count
  ami_id                  = var.ubuntu_ami[var.aws_region]
  vpc_id                  = module.vpc.vpc_id
  vpc_zone_identifier     = module.vpc.public_subnets
}
