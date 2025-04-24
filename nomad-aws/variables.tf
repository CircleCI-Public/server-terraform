variable "aws_region" {
  type        = string
  description = "The AWS region"
  default     = ""
}
variable "subnet" {
  type        = string
  description = "Subnet ID"
  default     = ""
}

variable "subnets" {
  type        = list(string)
  description = "Subnet IDs"
  default     = [""]
}

variable "security_group_id" {
  type        = list(string)
  description = <<-EOF
    ID for the security group for Nomad clients.
    See security documentation for recommendations.
  EOF
  default     = []
}

variable "nomad_server_hostname" {
  type        = string
  description = "Hostname of RPC service of Nomad control plane (e.g circleci.example.com)"
  validation {
    condition     = !can(regex(":", var.nomad_server_hostname))
    error_message = "Found ':' in hostname. Port cannot be specified."
  }
}

variable "nomad_server_port" {
  type        = number
  description = "Port that the server endpoint listens on for nomad connections."
  default     = 4647
}

variable "blocked_cidrs" {
  type        = list(string)
  description = <<-EOF
    List of CIDR blocks to block access to from within jobs, e.g. your K8s nodes.
    You won't want to block access to external VMs here.
    It's okay when your dns_server is within a blocked CIDR block, you can use var.dns_server to create an exemption.
    EOF
}

variable "docker_network_cidr" {
  type        = string
  description = <<-EOF
    IP CIDR to be used in docker networks when running job on nomad client.
    This CIDR block should not be the same as your VPC CIDR block.
    i.e - "10.10.0.0/16" or "172.32.0.0/16" or "192.168.0.0/16"
    EOF
  default     = "10.10.0.0/16"
}

variable "dns_server" {
  type        = string
  description = "If the IP address of your VPC DNS server is within one of the blocked CIDR blocks you can create an exemption by entering the IP address for it here"
}

variable "nodes" {
  type        = number
  description = "Number of nomad clients to create"
}

variable "max_nodes" {
  type        = number
  default     = 5
  description = "Maximum number of nomad clients to create. Must be greater than or equal to nodes"
}

variable "volume_type" {
  type        = string
  description = "The EBS volume type of the node. If gp3 is not available in your desired region, switch to gp2"
  default     = "gp3"
}

variable "instance_type" {
  type        = string
  description = "AWS Node type for instance. Must be Intel linux type"
  default     = "t3.2xlarge"
}

variable "ssh_key" {
  type        = string
  description = "SSH Public key to access nomad nodes"
  default     = null
}

variable "enable_mtls" {
  type        = bool
  default     = true
  description = "MTLS support for Nomad traffic. Modifying this can be dangerous and is not recommended."
}

variable "basename" {
  type        = string
  description = "Name used as prefix for AWS resources"
  default     = ""
}

variable "vpc_id" {
  type        = string
  description = "VPC ID of VPC used for Nomad resources"
}

variable "instance_tags" {
  type = map(string)
  default = {
    "vendor" = "circleci"
  }
}

variable "launch_template_version" {
  type        = string
  description = "Specific version of the instance template"
  default     = "$Latest"
}

variable "role_name" {
  type        = string
  description = "Name of the role to add to the instance profile"
  default     = null
}

# Check for IRSA Role (more details)  - https://docs.aws.amazon.com/eks/latest/userguide/associate-service-account-role.html
#   enable_irsa  = {
#                  oidc_principal_id  = "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>"
#                  oidc_eks_variable  = "oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>:sub"
#                  k8s_service_account = "system:serviceaccount:<NAMESPACE>:nomad-autoscaler"
#                  }
variable "nomad_auto_scaler" {
  type        = bool
  default     = false
  description = "If set to true, A Nomad User or A Role will be created based on enable_irsa variable values"
}

variable "enable_irsa" {
  type        = map(any)
  default     = {}
  description = "If passed a valid OIDC MAP, terraform will create K8s Service Account Role to be used by nomad autoscaler."
}

variable "disk_size_gb" {
  type        = number
  default     = 100
  description = "The volume size, in GB to each nomad client's /dev/sda1 disk."
}


locals {
  tags = merge({ "nomad-environment" = var.basename }, var.instance_tags)

  # If nomad_auto_scaler is true and enable_irsa is empty - set autoscaler_type=user
  # If nomad_auto_scaler is true and enable_irsa is not empty - set autoscaler_type=role
  # Else ""
  autoscaler_type = var.nomad_auto_scaler && length(var.enable_irsa) == 0 ? "user" : var.nomad_auto_scaler && length(var.enable_irsa) > 0 ? "role" : ""

}

variable "machine_image_owners" {
  type        = list(string)
  description = "List of AWS account IDs that own the images to be used for nomad virtual machines."
  default     = ["833371238208"]
}

variable "machine_image_names" {
  type        = list(string)
  description = "Strings to filter image names for nomad virtual machine images."
  default     = ["CircleCIServerNomad*"]
}

variable "nomad_version" {
  type        = string
  description = "The version of Nomad to install"
  default     = "1.9.7-1"
}

variable "allowed_ips_retry_ssh" {
  type        = list(string)
  description = "List of IPv4 ranges that are permitted to access nomad nodes for the retry-with-ssh feature"
  default     = ["0.0.0.0/0"]
}

variable "allowed_ips_circleci_server_nomad_access" {
  type        = list(string)
  description = "List of IPv4 ranges that are permitted to access nomad nodes; used for circleci-server-to-nomad communication"
  default     = ["0.0.0.0/0"]
}

variable "enable_imdsv2" {
  type        = string
  description = "Enable or Disable IMDSv2 on Nomad clients. Optional or Required. This is only supported on, or after, CircleCI Server 4.6.0"
  default     = "optional"
}

variable "nomad_server_enabled" {
  type        = bool
  default     = false
  description = "Set to true to enable nomad server"
}

variable "min_server_replicas" {
  type        = number
  default     = 5
  description = "Minimum number of Nomad Server instances"
}

variable "max_server_replicas" {
  type        = number
  default     = 7
  description = "Maximum number of Nomad Server instances"
}

variable "server_disk_size_gb" {
  type        = number
  default     = 20
  description = "Disk size for nomad server instances"
}

variable "server_machine_type" {
  type        = string
  description = "The instance type of the EC2 Nomad Servers."
  default     = "m4.xlarge"
}

variable "server_ssh_key" {
  type        = string
  description = "An SSH key you wish to attach to SSH into the nomad-server instances. Must allow port 22"
  default     = null
}

variable "allow_ssh" {
  description = "Enable SSH access inbound (true/false)"
  type        = bool
  default     = false
}

variable "server_public_ip" {
  type        = bool
  default     = false
  description = "Should the EC2 instances have a public IP?"
  validation {
    condition     = var.server_public_ip == true || var.server_public_ip == false
    error_message = "The value for public_ip must be either true or false."
  }
}

variable "tag_key_for_discover" {
  type        = string
  description = "The tag key placed on each EC2 instance for Nomad Server discoverability."
  default     = "identifier"
}

variable "tag_value_for_discover" {
  type        = string
  description = "The tag value placed on each EC2 instance for Nomad Server discoverability."
  default     = "nomad-server-instance"
}

variable "addr_type" {
  type        = string
  description = "What IP should the Nomad servers discover"
  default     = "private_v4"
  validation {
    condition     = contains(["private_v4"], var.addr_type)
    error_message = "This variable must be 'private_v4'."
  }
}
