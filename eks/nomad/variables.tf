variable "basename" {
  default = ""
}

variable "nomad_instance_type" {
  default = "m5.2xlarge"
}

variable "aws_subnet_cidr_block" {
  default = "10.0.0.0/16"
}

variable "sg_enabled" {
  default = 1
}

variable "nomad_count" {
  type    = number
  default = 1
}

variable "ami_id" {
  description = "AMI used as the base operating system."
}

variable "vpc_id" {
}

variable "vpc_zone_identifier" {
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block of the VPC to prevent access from jobs"
}

variable "vm_subnet_cidr" {
  type        = string
  description = "The CIDR block of the VM subnet to enable jobs to run on external VMs"
}

variable "private_clients" {
  type        = bool
  default     = false
  description = "Determine whether to assign public IPv4 addresses to the Nomad clients or not. Make sure that this setting matches the settings for the subnets passed in via `vpc_zone_identifier`"
}

variable "ssh_allowed_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "List of allowed source IP addresses that can access Nomad clients via SSH. Has no effect if `ssh_key` not set."
}

variable "ssh_key" {
  type        = string
  default     = null
  description = "SSH key to authenticate access to Nomad clients. If not set, SSH is disabled"
}

variable "enable_mtls" {
  type        = bool
  default     = true
  description = "mTLS support for Nomad traffic. Modifying this can be dangerous and is not recommended."
}
