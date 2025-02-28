variable "aws_region" {
    type        = string
    description = "The AWS region that you are in."
}

variable "vpc_cidr_range" {
    type        = string
    description = "The default CIDR range."
    default     = "10.0.1.0/24"
}

variable "vpc_subnet_range" {
    type        = string
    description = "The default subnet range."
    default     = "10.0.1.64/26"
}

variable "nomad_server_hostname" {
  type        = string
  description = "Hostname of the nomad server."
}

variable "nomad_server_port" {
  type        = number
  description = "Port that the nomad server endpoint listens on."
  default     = 4647
}

#
#Variables for Launch Template
#
variable "enable_imdsv2" {
    type        = string
    description = "To enable or dsiable IMDSv2. (optional/required)"
    default     = "required"
    validation {
      condition     = contains(["optional", "required"], var.enable_imdsv2)
      error_message = "This variable must be 'enabled' or 'optional'"
    }
}


variable "launch_template_instance_type" {
    type        = string
    description = "The instance type of the EC2 Nomad Servers."
    default     = "t2.micro"
}

variable "ssh_key_name" {
    type = string
    description = "The SSH key you'd like to be on the Nomad Server instances."
    default = null
}

variable "disk_size_gb" {
  type        = number
  default     = 20
  description = "The volume size, in GB to each nomad client's /dev/sda1 disk."
}

variable "public_ip" {
  type        = bool
  default     = false
  description = "Should the EC2 instances have a public IP?"
  validation {
    condition     = var.public_ip == true || var.public_ip == false
    error_message = "The value for public_ip must be either true or false."
  }
}

#
#Variables for aws ami
#
variable "machine_image_owners" {
  type        = list(string)
  description = "List of AWS account IDs that own the images to be used for nomad virtual machines."
  default     = ["099720109477"]
}

variable "machine_image_names" {
  type        = list(string)
  description = "Strings to filter image names for nomad server virtual machine images."
  default     = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
}

#
#Variables for ASG
#
variable "asg_name" {
    type        = string
    description = "Name of the auto scaling group."
    default = "circleci-nomad-server-asg"
}

variable "desired_capacity" {
    type        = number
    description = "Desired capacity of Nomad Server Instances."
    default     = 5
    validation {
      condition     = var.desired_capacity >= 3
      error_message = "Nomad server requires a minimum of 3 instances."
    }
}

variable "min_size" {
    type        = number
    description = "Minimum size of the Nomad server cluster."
    default     = 3
    validation {
      condition     = var.min_size >= 3
      error_message = "Nomad server requires a minimum of 3 instances."
    }
}

variable "max_size" {
    type        = number
    description = "Max size of the ASG."
    default     = 7
}

variable "name_prefix_launch_template" {
    type        = string
    description = "Name prefix of your launch template."
    default = "circleci-nomad-server-launch-template"
}

variable "tag_key_name_value" {
    type        = string
    description = "Value fo the name you want to name the EC2 instance."
    default     = "nomad-server"
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

variable "vpc_zones_id" {
    type = list(string)
    description = "A list of the VPC zones that you wish the ASG to use encased in []"
}

#
#Variables for cloud init config
#

variable "cloud_provider" {
    type        = string
    description = "Provider for nomad server discover. Must be aws or gcp"
    default = "aws"
    validation {
      condition     = contains(["aws"], var.cloud_provider)
      error_message = "This variable must be 'aws'"
    }
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

#
#IAM role configuration
#
variable "nomad_role_name" {
    type        = string
    description = "The name of the role that needs to be attached to the Nomad server instances."
    default     = "circleci-nomad-server-role"
}

variable "nomad_instance_profile_name" {
    type        = string
    description = "The name of the instance profile that needs to be attached to the Nomad server instances."
    default     = "circleci-nomad-server-instance-profile"
}

#
#NLB Variables
#

variable "target_group_name" {
  description = "The name of the target group"
  type        = string
  default     = "circleci-nomad-server-target-grp"
}

# variable "vpc_id" {
#   description = "The VPC ID where the NLB will be created"
#   type        = string
# }

#
#Tags and Names
#
variable "tags" {
    type        = map(string)
    description = "Map of tags you'd like to add to the Launch Template and ASG."
    default     = {
        "type"  = "nomad-server"
        "owner" = "circleci"
    }
}

variable "subnet_name" {
    type        = string
    description = "Name of the Subnet"
    default     = "circleci-nomad-server-subnet"
}
variable "internet_gateway_name" {
    type        = string
    description = "Name of the Internet Gateway"
    default     = "circleci-nomad-server-igw"
}
variable "route_table_name" {
    type        = string
    description = "Name of the Route Table"
    default     = "circleci-nomad-server-rt"
}
variable "nlb_name" {
    type        = string
    description = "Name of the Internal NLB"
    default     = "circleci-nomad-server-nlb"
}
variable "vpc_name" {
    type        = string
    description = "Name of the VPC"
    default     = "circleci-nomad-server-vpc"
}
variable "sg_name" {
    type        = string
    description = "Name of the Security Group"
    default     = "circleci-nomad-server-sg"
}

variable "tls_cert" {
  type        = string
  default     = ""
  description = "TLS certificate for nomad server"
}

variable "tls_ca" {
  type        = string
  default     = ""
  description = "TLS CA for nomad server"

}

variable "tls_key" {
  type        = string
  default     = ""
  description = "TLS key for nomad server"
}

variable "allow_ssh" {
  description = "Enable SSH access inbound (true/false)"
  type        = bool
  default     = false
}