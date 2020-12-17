data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.basename}-circleci"
  cidr = var.aws_vpc_cidr_block

  azs = data.aws_availability_zones.available.names

  # Public segment of VPC hosts public load balancers, nomad clients (for SSH access),
  # NAT gateways for the private segment.
  public_subnets = var.aws_vpc_public_cidr_blocks

  # Private segment of VPC hosts internal load balancers, EKS pods and nodes.
  private_subnets = var.aws_vpc_private_cidr_blocks

  enable_nat_gateway = true
  single_nat_gateway = true

  # VPC Internal DNS is required for service discovery. DNS hostnames is needed
  # for this to work, but it is unclear why.
  enable_dns_hostnames = true
  enable_dns_support   = true

  # See https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html for
  # sub-net tagging details
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }

  tags = {
    Terraform   = "true"
    circleci    = true
    Environment = "circleci"
    Name        = "${var.basename}-circleci_vpc"
  }
}
