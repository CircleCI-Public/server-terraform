terraform {
  required_version = ">=0.15.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# An example VPC for demonstration. This might already exist if you deployed
# server in a preexisting VPC and want your nomad clients to run there,
# In that case, you should make the appropriate changes in this file.
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

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

  # prefix to add in AWS resources name
  basename = "cci"

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
    # Block access to private subnet. You may which to do this if you
    # Kubernetes cluster is some other resource you don't want your CI jobs to
    # access is running there.
    module.vpc.private_subnets[0]
  ]

  nomad_auto_scaler = true # If true, terraform will generate an IAM user to be used by nomad-autoscaler in CircleCI Server.
  max_nodes         = 5    # the max number of clients to scale to. Must be greater than our equal to the nodes set above.

  # enable_irsa input will allow K8s service account to use IAM roles, you have to replace REGION, ACCOUNT_ID, OIDC_ID and K8S_NAMESPACE with appropriate value
  # for more info, visit - https://docs.aws.amazon.com/eks/latest/userguide/create-service-account-iam-policy-and-role.html
  enable_irsa = {
    oidc_principal_id   = "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>"
    oidc_eks_variable   = "oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>:sub"
    k8s_service_account = "system:serviceaccount:<K8S_NAMESPACE>:nomad-autoscaler"
  }
}

output "nomad_module" {
  value = module.nomad-aws
}
