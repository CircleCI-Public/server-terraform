resource "aws_key_pair" "bastion_key" {
  count      = var.enable_bastion ? 1 : 0
  key_name   = "${var.basename}-circleci-bastion-key"
  public_key = var.bastion_key
  tags = {
    Terraform = "true"
    circleci  = "true"
  }
}

resource "aws_security_group" "bastion_ssh" {
  count       = var.enable_bastion ? 1 : 0
  name        = "${var.basename}-circleci-cluster-bastion_ssh"
  description = "Allow SSH access to bastion host"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "SSH inbound from allowed IPs"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.allowed_cidr_blocks
    ipv6_cidr_blocks = var.allowed_ipv6_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.basename}-circleci-cluster-bastion_ssh"
    Terraform   = "true"
    Environment = "circleci"
    circleci    = "true"
  }

  depends_on = [module.vpc]
}

resource "aws_iam_role" "bastion_role" {
  count       = var.enable_bastion ? 1 : 0
  name        = "${var.basename}-circleci-cluster-bastion_role"
  description = "IAM role for the EKS bastion host"

  assume_role_policy = <<EOF
{"Version": "2012-10-17","Statement": [{"Effect": "Allow","Principal": {"Service": ["ec2.amazonaws.com"]},"Action": ["sts:AssumeRole"]}]}
  EOF

  tags = {
    Name        = "${var.basename}-circleci-cluster-bastion_role"
    Terraform   = "true"
    Environment = "circleci"
    circleci    = "true"
  }
}

resource "aws_iam_policy" "bastion_policy" {
  count       = var.enable_bastion ? 1 : 0
  name        = "${var.basename}-circleci-cluster-bastion_policy"
  path        = "/"
  description = "IAM policy for the CircleCI Server EKS bastion host"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "eks:*",
        "sts:*",
        "iam:PassPolicy",
        "ec2:DescribeTags",
        "logs:*"
      ],
      "Resource": [
        "*"
      ],
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
  EOF
}

resource "aws_iam_role_policy_attachment" "bastion_policy_attachment" {
  count      = var.enable_bastion ? 1 : 0
  role       = aws_iam_role.bastion_role[0.0].name
  policy_arn = aws_iam_policy.bastion_policy[0.0].arn
}

resource "aws_iam_instance_profile" "bastion_iam_profile" {
  count = var.enable_bastion ? 1 : 0
  name  = "${var.basename}-circleci-bastion_iam_profile"
  role  = aws_iam_role.bastion_role[0.0].name
}

resource "aws_instance" "bastion" {
  count                       = var.enable_bastion ? 1 : 0
  ami                         = var.ubuntu_ami[var.aws_region]
  instance_type               = "t3.micro"
  associate_public_ip_address = true
  user_data                   = <<-EOF
          #! /bin/bash

          curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.17.9/2020-08-04/bin/linux/amd64/aws-iam-authenticator
          chmod +x ./aws-iam-authenticator
          sudo mv ./aws-iam-authenticator /usr/bin/.
          curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.14.10/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/bin/
          echo "${module.eks-cluster.kubeconfig}" > /etc/kube.config
          echo export KUBECONFIG=/etc/kube.config >> /etc/profile
          curl -LO https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv3.5.4/kustomize_v3.5.4_linux_amd64.tar.gz && tar xzf ./kustomize_v3.5.4_linux_amd64.tar.gz && sudo mv ./kustomize /usr/bin/
          curl -LO https://github.com/replicatedhq/kots/releases/download/v1.19.5/kots_linux_amd64.tar.gz && tar xzf kots_linux_amd64.tar.gz && sudo mv ./kots /usr/bin/kubectl-kots
          EOF

  key_name               = aws_key_pair.bastion_key[0.0].key_name
  vpc_security_group_ids = [module.vpc.default_security_group_id, aws_security_group.bastion_ssh[0.0].id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.bastion_iam_profile[0.0].name

  tags = {
    Terraform   = "true"
    circleci    = "true"
    Environment = "circleci"
    Name        = "${var.basename}-circleci-bastion"
  }
}
