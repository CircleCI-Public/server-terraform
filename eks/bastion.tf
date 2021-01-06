resource "aws_key_pair" "bastion_key" {
  count      = var.bastion_key != "" ? 1 : 0
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

  assume_role_policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": ["ec2.amazonaws.com"]
          },
          "Action": ["sts:AssumeRole"]
        }
      ]
    }
  EOF

  tags = {
    Name        = "${var.basename}-circleci-cluster-bastion_role"
    Terraform   = "true"
    Environment = "circleci"
    circleci    = "true"
  }
}

resource "aws_iam_policy" "bastion_access" {
  count       = var.enable_bastion ? 1 : 0
  name        = "${var.basename}-cci-cluster-bastion_access"
  path        = "/"
  description = "IAM policy for access to the EKS bastion host"

  policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "ec2-instance-connect:SendSSHPublicKey",
          "Resource": [ "${aws_instance.bastion[0].arn}" ],
          "Condition": {
            "StringEquals": {
              "ec2:osuser": "ubuntu"
            }
          }
        },
        {
          "Effect": "Allow",
          "Action": "ec2:DescribeInstances",
          "Resource": "*"
        }
      ]
    }
  EOF
}


resource "aws_iam_policy" "bastion_policy" {
  count       = var.enable_bastion ? 1 : 0
  name        = "${var.basename}-circleci-cluster-bastion_policy"
  path        = "/"
  description = "IAM policy for the CircleCI Server EKS bastion host"

  policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "eks:ListClusters",
            "eks:DescribeCluster"
          ],
          "Resource": "${module.eks-cluster.cluster_arn}",
          "Condition": {
            "StringEquals": {
              "aws:ResourceTag/kubernetes-cluster-name": "${local.cluster_name}"
            }
          }
        },
        {
          "Effect": "Allow",
          "Action": "ec2-instance-connect:SendSSHPublicKey",
          "Resource": "*",
          "Condition": {
            "StringEquals": {
                "ec2:ResourceTag/nomadclient": "true",
                "ec2:osuser": "ubuntu"
            }
          }
        },
        {
          "Effect": "Allow",
          "Action": "sts:AssumeRole",
          "Resource": %{if var.additional_bastion_role_arn != ""}["${aws_iam_role.bastion_role[0].arn}", "${var.additional_bastion_role_arn}"]%{else}"${aws_iam_role.bastion_role[0].arn}"%{endif}
        }
      ]
    }
  EOF
}

resource "aws_iam_role_policy_attachment" "bastion_policy_attachment" {
  count      = var.enable_bastion ? 1 : 0
  role       = aws_iam_role.bastion_role[0].name
  policy_arn = aws_iam_policy.bastion_policy[0].arn
}

resource "aws_iam_instance_profile" "bastion_iam_profile" {
  count = var.enable_bastion ? 1 : 0
  name  = "${var.basename}-circleci-bastion_iam_profile"
  role  = aws_iam_role.bastion_role[0].name
}

resource "aws_instance" "bastion" {
  count                       = var.enable_bastion ? 1 : 0
  ami                         = var.ubuntu_ami[var.aws_region]
  instance_type               = "t3.micro"
  associate_public_ip_address = true
  user_data                   = <<-EOF
    #!/bin/bash
    sudo apt update -y
    echo ### INSTALLING PACKAGES ###
    sudo apt install -y awscli ec2-instance-connect python-pip jq
    pip install ec2instanceconnectcli
    echo ### CONFIGURING AWS CREDENTIALS ###
    mkdir /home/ubuntu/.aws
    cat <<- EOT > /home/ubuntu/.aws/credentials
    [instance]
    role_arn = ${aws_iam_role.bastion_role[0].arn}
    credential_source = Ec2InstanceMetadata
    region = ${var.aws_region}
    EOT
    chown -R ubuntu /home/ubuntu/.aws
    mkdir ~/.aws
    cat <<- EOT > ~/.aws/credentials
      [default]
      role_arn = ${aws_iam_role.bastion_role[0].arn}
      credential_source = Ec2InstanceMetadata
      region = ${var.aws_region}
    EOT
    echo ### CONFIGURING UBUNTU .bashrc ###
    cat <<- EOT > /home/ubuntu/.bashrc
      export AWS_PROFILE=instance
      alias k=kubectl
      source <(kubectl completion bash)
      update-kubeconfig
    EOT
    chown ubuntu /home/ubuntu/.bashrc

    echo ### INSTALLING ADDITIONAL K8s SOFTWARE ###
    curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.20.0/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/bin/
    curl -LO https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv3.8.8/kustomize_v3.8.8_linux_amd64.tar.gz && tar xzf ./kustomize_v3.8.8_linux_amd64.tar.gz && sudo mv ./kustomize /usr/bin/
    curl -LO https://github.com/replicatedhq/kots/releases/download/v1.25.2/kots_linux_amd64.tar.gz && tar xzf kots_linux_amd64.tar.gz && sudo mv ./kots /usr/bin/kubectl-kots
    curl -LO https://github.com/replicatedhq/troubleshoot/releases/download/v0.9.54/preflight_linux_amd64.tar.gz && tar xzf preflight_linux_amd64.tar.gz && sudo mv ./preflight /usr/bin/kubectl-preflight

    echo ### CONFIGURING EKS AUTH ###
    cat <<- EOT > ~/aws-auth-cm.yaml
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: aws-auth
        namespace: kube-system
      data:
        mapRoles: |
          - rolearn: ${aws_iam_role.bastion_role[0].arn}
            username: cluster-admin
            groups:
              - system:masters
    EOT
    aws eks update-kubeconfig --name ${local.cluster_name} --region ${var.aws_region} --role-arn ${var.additional_bastion_role_arn}
    kubectl apply -f ~/aws-auth-cm.yaml --kubeconfig=/root/.kube/config
    echo aws eks update-kubeconfig --name ${local.cluster_name} --region ${var.aws_region} > /usr/bin/update-kubeconfig
    chmod +x /usr/bin/update-kubeconfig
    echo ### END OF USER DATA ###
  EOF

  key_name               = aws_key_pair.bastion_key != [] ? aws_key_pair.bastion_key[0.0].key_name : null
  vpc_security_group_ids = [module.vpc.default_security_group_id, aws_security_group.bastion_ssh[0.0].id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.bastion_iam_profile[0].name

  tags = merge({
    Terraform   = "true"
    circleci    = "true"
    Environment = "circleci"
    Name        = "${var.basename}-circleci-bastion"
  }, var.additional_bastion_tags)
}
