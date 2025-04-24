variable "aws_region" {
  type        = string
  description = "The AWS region that you are in."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID of VPC used for Nomad resources"
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

variable "basename" {
  type        = string
  description = "Name used as prefix for AWS resources"
  default     = ""
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

variable "ssh_key" {
  type        = string
  description = "The SSH key you'd like to be on the Nomad Server instances."
  default     = null
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
  default     = ["099720109477", "513442679011"]
}

variable "machine_image_names" {
  type        = list(string)
  description = "Strings to filter image names for nomad virtual machine images."
  default     = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
}

#
#Variables for ASG
#
variable "desired_capacity" {
  type        = number
  description = "Desired capacity of Nomad Server Instances."
  default     = 3
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

#
#Tags and Names
#
variable "tags" {
  type        = map(string)
  description = "Map of tags you'd like to add to the Launch Template and ASG."
  default = {
    "vender" = "circleci"
  }
}


variable "launch_template_version" {
  type        = string
  description = "Specific version of the instance template"
  default     = "$Latest"
}

variable "tag_key_for_discover" {
  type        = string
  description = "The tag key placed on each EC2 instance for Nomad Server discoverability."
  default     = "identifier"
}

variable "tag_value_for_discover" {
  type        = string
  description = "The tag value placed on each EC2 instance for Nomad Server discoverability."
  default     = "circleci-nomad-server-instance"
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

variable "random_string_suffix" {
  description = "Random String"
  type        = string
}

variable "server_retry_join" {
  description = "Server Identifier to join the cluster"
  default     = ""
  type        = string
}