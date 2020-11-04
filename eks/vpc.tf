data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.basename}-circleci"
  cidr = "10.0.0.0/16"

  azs = data.aws_availability_zones.available.names

  # Public segment of VPC hosts public load balancers, nomad clients (for SSH access),
  # NAT gateways for the private segment.
  public_subnets = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]

  # Private segment of VPC hosts internal load balancers, EKS pods and nodes.
  private_subnets = ["10.0.96.0/19", "10.0.128.0/19", "10.0.160.0/19"]

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
