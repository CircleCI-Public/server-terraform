terraform {
  required_version = ">=0.15.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# An example VPC for demonstration. This might already exist if you deployed
# server in a preexisting VPC and want your nomad clients to run there.
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name                 = "nomad-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = ["us-east-1a"]
  public_subnets       = ["10.0.0.0/24"]
  private_subnets      = ["10.0.1.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
}

module "nomad-aws" {
  source = "../.."

  # Number of nomad clients to run
  nodes = 4

  subnet = module.vpc.public_subnets[0]
  vpc_id = module.vpc.vpc_id

  # Location of your Nomad server endpoint. This should be exposed from your
  # server installation via a load balancer service.
  server_endpoint = "example.com:4647"

  # AWS DNS Server runs on the third IP address of the VPC block. We define it
  # here to allow access to if from the Nomad clients.
  dns_server = "10.0.0.2"

  blocked_cidrs = [
    # Block access to private subnet. You may which to do this if you
    # Kubernetes cluster is some other resource you don't want your CI jobs to
    # access is running there.
    module.vpc.private_subnets[0]
  ]

  # cidr block you’d like to use in docker within nomad client, should not be same as subnet cidr block
  docker_network_cidr = "192.168.0.0/16"

  nomad_auto_scaler = false # If true, terraform will generate an IAM user to be used by nomad-autoscaler in CircleCI Server. The keys will be available in terraform's output
  max_nodes         = 5     # the max number of clients to scale to. Must be greater than our equal to the nodes set above.
}

output "nomad_module" {
  value = module.nomad-aws
}
