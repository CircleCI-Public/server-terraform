data "aws_eks_cluster" "cluster" {
  name = module.eks-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks-cluster.cluster_id
}

locals {
  cluster_name = "${var.basename}-cci-cluster"
  k8s_version  = "1.18"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.11"
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
  map_roles = var.enable_bastion ? concat(
    var.k8s_roles,
    [
      {
        rolearn  = aws_iam_role.bastion_role[0].arn
        username = "bastion"
        groups   = ["system:masters"]
      }
    ]
  ) : []
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

resource "aws_iam_policy" "data-full-access" {
  name        = "${var.basename}-data-full-access"
  description = "Allows ressources access to CircleCI Server S3 buckets"
  policy      = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "s3:*"
          ],
          "Resource": [
            "${aws_s3_bucket.data_bucket.arn}",
            "${aws_s3_bucket.data_bucket.arn}/*"
          ]
        }
      ]
    }
  EOF
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = module.eks-cluster.worker_iam_role_name
  policy_arn = aws_iam_policy.data-full-access.arn
}

resource "aws_iam_policy" "output_processor_sts" {
  // Output processor uses STS to create short lived credentials. This policy
  // allows output processor to get and assume the role of the nodes its
  // already on.
  name        = "${var.basename}-output-processor-sts"
  description = "Allows output process to assume node role and use STS"
  policy      = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": [
            "iam:GetRole",
            "sts:AssumeRole"
          ],
          "Resource": [
            "${module.eks-cluster.worker_iam_role_arn}"
          ],
          "Effect": "Allow"
        }
      ]
    }
  EOF
}

resource "aws_iam_role_policy_attachment" "output_processor_sts" {
  role       = module.eks-cluster.worker_iam_role_name
  policy_arn = aws_iam_policy.output_processor_sts.arn
}

resource "aws_iam_policy" "vm-service-ec2" {
  name        = "${var.basename}-vm-service-ec2"
  description = "Security group for CircleCI Server VM Service EC2 instances"
  policy      = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "ec2:RunInstances",
          "Effect": "Allow",
          "Resource": [
            "arn:aws:ec2:*::image/*",
            "arn:aws:ec2:*::snapshot/*",
            "arn:aws:ec2:*:*:key-pair/*",
            "arn:aws:ec2:*:*:launch-template/*",
            "arn:aws:ec2:*:*:network-interface/*",
            "arn:aws:ec2:*:*:placement-group/*",
            "arn:aws:ec2:*:*:volume/*",
            "arn:aws:ec2:*:*:subnet/*",
            "arn:aws:ec2:*:*:security-group/${aws_security_group.eks_nomad_sg[0].id}"
          ]
        },
        {
          "Action": "ec2:RunInstances",
          "Effect": "Allow",
          "Resource": "arn:aws:ec2:*:*:instance/*",
          "Condition": {
            "StringEquals": {
              "aws:RequestTag/ManagedBy": "circleci-vm-service"
            }
          }
        },
        {
          "Action": [
            "ec2:CreateVolume"
          ],
          "Effect": "Allow",
          "Resource": [
            "arn:aws:ec2:*:*:volume/*"
          ],
          "Condition": {
            "StringEquals": {
              "aws:RequestTag/ManagedBy": "circleci-vm-service"
            }
          }
        },
        {
          "Action": [
            "ec2:Describe*"
          ],
          "Effect": "Allow",
          "Resource": "*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "ec2:CreateTags"
          ],
          "Resource": "arn:aws:ec2:*:*:*/*",
          "Condition": {
            "StringEquals": {
              "ec2:CreateAction" : "CreateVolume"
            }
          }
        },
        {
          "Effect": "Allow",
          "Action": [
            "ec2:CreateTags"
          ],
          "Resource": "arn:aws:ec2:*:*:*/*",
          "Condition": {
            "StringEquals": {
              "ec2:CreateAction" : "RunInstances"
            }
          }
        },
        {
          "Action": [
            "ec2:CreateTags",
            "ec2:StartInstances",
            "ec2:StopInstances",
            "ec2:TerminateInstances",
            "ec2:AttachVolume",
            "ec2:DetachVolume",
            "ec2:DeleteVolume"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:ec2:*:*:*/*",
          "Condition": {
            "StringEquals": {
              "ec2:ResourceTag/ManagedBy": "circleci-vm-service"
            }
          }
        },
        {
          "Action": [
            "ec2:RunInstances",
            "ec2:StartInstances",
            "ec2:StopInstances",
            "ec2:TerminateInstances"
          ],
          "Effect": "Allow",
          "Resource": "arn:aws:ec2:*:*:subnet/*",
          "Condition": {
            "StringEquals": {
              "ec2:Vpc": "${module.vpc.vpc_arn}"
            }
          }
        }
      ]
    } 
  EOF
}

resource "aws_iam_role_policy_attachment" "vm_ec2_access" {
  role       = module.eks-cluster.worker_iam_role_name
  policy_arn = aws_iam_policy.vm-service-ec2.arn
}

resource "aws_iam_policy" "external_dns" {
  name        = "${var.basename}-external-dns-policy"
  description = "IAM Policy to allow the external-dns service to set DNS records"
  policy      = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "route53:ChangeResourceRecordSets"
          ],
          "Resource": [
            "arn:aws:route53:::hostedzone/*"
          ]
        },
        {
          "Effect": "Allow",
          "Action": [
            "route53:ListHostedZones",
            "route53:ListResourceRecordSets"
          ],
          "Resource": [
            "*"
          ]
        }
      ]
    }
  EOF
}

resource "aws_iam_role_policy_attachment" "external_dns_route53_access" {
  role       = module.eks-cluster.worker_iam_role_name
  policy_arn = aws_iam_policy.external_dns.arn
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
