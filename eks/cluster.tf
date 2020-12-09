locals {
  cluster_name = "${var.basename}-cci-cluster"
  k8s_version  = "1.18"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks-cluster.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

module "eks-cluster" {
  version                         = "13.0.0"
  source                          = "terraform-aws-modules/eks/aws"
  cluster_name                    = local.cluster_name
  cluster_version                 = local.k8s_version
  cluster_endpoint_private_access = var.enable_bastion ? true : false
  cluster_endpoint_public_access  = true
  vpc_id                          = module.vpc.vpc_id
  subnets                         = module.vpc.private_subnets
  cluster_enabled_log_types       = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  wait_for_cluster_cmd            = "for i in `seq 1 60`; do curl -k -s $ENDPOINT/healthz >/dev/null && exit 0 || true; sleep 5; done; echo TIMEOUT && exit 1"
  map_roles = [
    {
      rolearn  = aws_iam_role.bastion_role.arn
      username = "bastion"
      groups   = ["system:masters"]
    }
  ]
  map_users = var.k8s_administrators

  node_groups = {
    circleci-server = {
      version                       = local.k8s_version
      instance_type                 = var.instance_type
      max_capacity                  = var.max_capacity
      min_capacity                  = var.min_capacity
      desired_capacity              = var.desired_capacity
      additional_security_group_ids = [aws_security_group.eks_nomad_sg[0].id]
    }
  }

  tags = {
    env                     = "CircleCI"
    kubernetes-cluster-name = local.cluster_name
    circleci                = "true"
    Terraform               = "true"
    Name                    = "${var.basename}-circleci-eks_cluster"
  }
}

resource "aws_security_group_rule" "eks_api_access" {
  count                    = var.enable_bastion ? 1 : 0
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_ssh[0.0].id
  security_group_id        = module.eks-cluster.cluster_security_group_id
  description              = "Allow CircleCI Bastion SG to communicate with the EKS cluster API."
}

resource "aws_security_group" "eks_nomad_sg" {
  count       = var.sg_enabled
  name        = "${var.basename}-circleci-vm-nomad-sg"
  description = "SG for communication between nomad and vm-service for CircleCI Server"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 2376
    to_port         = 2376
    protocol        = "tcp"
    security_groups = [module.nomad.nomad_sg_id, module.eks-cluster.cluster_primary_security_group_id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [module.nomad.nomad_sg_id, module.eks-cluster.cluster_primary_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
