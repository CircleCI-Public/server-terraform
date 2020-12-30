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
  default     = "ami-0cfee17793b08a293"
  description = "Default Ubuntu ami for us-east-1"
}

variable "vpc_id" {
}

variable "vpc_zone_identifier" {
}

variable "ssh_allowed_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "List of allowed source IP addresses that can access Nomad clients via SSH. Has no effict if `ssh_key` not set."
}

variable "ssh_key" {
  type        = string
  default     = null
  description = "SSH key to authenticate access to Nomad clients. If not set, SSH is disabled"
}

variable "enable_mtls" {
  type        = bool
  default     = true
  description = "MTLS support for Nomad traffic. Modifying this can be dangerous and is not recommended."
}