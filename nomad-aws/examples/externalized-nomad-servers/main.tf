terraform {
  required_version = ">=1.1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# An example VPC for demonstration. This might already exist if you deployed
# server in a preexisting VPC and want your nomad clients to run there.
module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  version              = "4.0.2"
  name                 = "nomad-vpc"
  cidr                 = "192.168.0.0/16"
  azs                  = ["us-east-1a"]
  public_subnets       = ["192.168.0.0/24"]
  private_subnets      = ["192.168.1.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
}

module "nomad-aws" {
  source = "../.."

  basename = "mytest"

  # Number of nomad clients to run
  nodes = 4

  subnet = module.vpc.public_subnets[0]
  vpc_id = module.vpc.vpc_id

  # Location of your Nomad server endpoint. This should be exposed from your
  # server installation via a load balancer service.
  nomad_server_hostname = "example.com"

  # AWS DNS Server runs on the third IP address of the VPC block. We define it
  # here to allow access to if from the Nomad clients.
  dns_server = "192.168.0.2"

  blocked_cidrs = [
    # Block access to private subnet. You may wish to do this if your
    # Kubernetes cluster (or some other resources you don't want your CI jobs to
    # access) is running there.
    module.vpc.private_subnets[0]
  ]
  nomad_auto_scaler = false # If true, terraform will generate an IAM user to be used by nomad-autoscaler in CircleCI Server. The keys will be available in terraform's output
  max_nodes         = 5     # the max number of clients to scale to. Must be greater than our equal to the nodes set above.

  # Externalized Nomad Servers
  deploy_nomad_server_instances = true
  server_public_ip              = true
  allow_ssh                     = true
  ssh_key                       = "<your-public-key>"
  server_machine_type           = "t3a.micro"
  max_server_instances          = 7
  desired_server_instances      = 3
  aws_region                    = "us-east-1"
}

output "nomad_module" {
  value = module.nomad-aws
}
