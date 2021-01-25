variable "basename" {
  default = ""

  validation {
    condition     = length(var.basename) < 21
    error_message = "Your basename is too long. Ensure that it doesn't exceed 20 characters in length."
  }
}

variable "aws_profile" {
  default     = ""
  description = "If using multiple profiles locally in a multi-account setup, this allows you to choose one"
}

variable "aws_region" {
  default     = "us-east-1"
  description = "Default AWS region"
}

variable "enable_bastion" {
  default = false
}

variable "enable_k8s_private_endpoint" {
  type        = bool
  default     = true
  description = "Determines whether the k8s API endpoint is reachable within the VPC"
}

variable "enable_k8s_public_endpoint" {
  type        = bool
  default     = true
  description = "Determines whether the k8s API endpoint is reachable from the public internet"
}

variable "k8s_administrators" {
  default = []
}

variable "k8s_roles" {
  default = []
}

variable "force_destroy" {
  default = false
}

variable "bastion_key" {
  default = ""
}

variable "aws_vpc_cidr_block" {
  default = "10.0.0.0/16"
}

variable "aws_vpc_public_cidr_blocks" {
  default = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]
}

variable "aws_vpc_private_cidr_blocks" {
  default = ["10.0.96.0/19", "10.0.128.0/19", "10.0.160.0/19"]
}

variable "allowed_cidr_blocks" {
  default = ["0.0.0.0/0"]
}

variable "allowed_ipv6_cidr_blocks" {
  default = ["::/0"]
}

variable "sg_enabled" {
  default = 1
}

variable "nomad_instance_type" {
  default = "m5.2xlarge"
}

variable "ubuntu_ami" {
  default = {
    ap-east-1      = "ami-736d1602"
    ap-northeast-1 = "ami-096c57cee908da809"
    ap-northeast-2 = "ami-0a25005e83c56767a"
    ap-northeast-3 = "ami-04c5893bcd93bc072"
    ap-southeast-1 = "ami-04613ff1fdcd2eab1"
    ap-southeast-2 = "ami-000c2343cf03d7fd7"
    ap-south-1     = "ami-03dcedc81ea3e7e27"
    ca-central-1   = "ami-0eb3e12d3927c36ef"
    cn-north-1     = "ami-05bf8d3ead843c270"
    cn-northwest-1 = "ami-09081e8e3d61f4b9e"
    eu-central-1   = "ami-0085d4f8878cddc81"
    eu-north-1     = "ami-4bd45f35"
    eu-west-1      = "ami-03746875d916becc0"
    eu-west-2      = "ami-0cbe2951c7cd54704"
    eu-west-3      = "ami-080d4d4c37b0aa206"
    sa-east-1      = "ami-09beb384ba644b754"
    us-east-1      = "ami-0cfee17793b08a293"
    us-east-2      = "ami-0f93b5fd8f220e428"
    us-gov-east-1  = "ami-0933d278"
    us-gov-west-1  = "ami-1580c474"
    us-west-1      = "ami-09eb5e8a83c7aa890"
    us-west-2      = "ami-0b37e9efc396e4c38"
  }
}

variable "nomad_count" {
  type    = number
  default = 1
}

variable "nomad_ssh_key" {
  type        = string
  default     = null
  description = "SSH key to authenticate access to Nomad clients. If not set SSH access is disabled"
}

variable "private_nomad_clients" {
  type        = bool
  default     = false
  description = "Set this to true to have Nomad clients deployed into a private subnet without public IPv4 addresses"
}

variable "instance_type" {
  type        = string
  default     = "m4.xlarge"
  description = "The machine types used to create nodes"
}

variable "max_capacity" {
  type        = number
  default     = 7
  description = "The maximun number of worker nodes in the cluster"
}

variable "min_capacity" {
  type        = number
  default     = 5
  description = "The minimum number of worker nodes in the cluster"
}

variable "desired_capacity" {
  type        = number
  default     = 5
  description = "The desired number of worker nodes in the cluster.  Changes to this value are not respected by terraform per: https://github.com/terraform-aws-modules/terraform-aws-eks/issues/835"
}

variable "enable_mtls" {
  type        = bool
  default     = true
  description = "MTLS support for Nomad traffic. Modifying this can be dangerous and is not recommended."
}

variable "nomad_ami_id" {
  type        = string
  default     = ""
  description = "Base AMI used for the Nomad client "
}
