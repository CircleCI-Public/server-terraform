variable "basename" {
  default = ""
}

variable "nomad_instance_type" {
  default = "m5.2xlarge"
}

variable "allowed_cidr_blocks" {
  default = ["0.0.0.0/0"]
}

variable "aws_subnet_cidr_block" {
  default = ["10.0.0.0/16"]
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