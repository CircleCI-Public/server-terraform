variable "region" {
  type        = string
  description = "AWS Region"
}

variable "subnet" {
  type        = string
  description = "Subnet ID"
}

variable "security_group_id" {
  type        = list(string)
  description = <<-EOF
    ID for the security group for Nomad clients.
    See security documentation for recommendations.
  EOF
  default     = []
}

variable "server_endpoint" {
  type        = string
  description = "Domain and port of RPC service of Nomad control plane (e.g example.com:4647)"
}

variable "blocked_cidrs" {
  type        = list(string)
  description = <<-EOF
    List of CIDR blocks to block access to from within jobs, e.g. your K8s nodes.
    You won't want to block access to external VMs here.
    It's okay when your dns_server is within a blocked CIDR block, you can use var.dns_server to create an exemption.
    EOF
}

variable "dns_server" {
  type        = string
  description = "If the IP address of your VPC DNS server is within one of the blocked CIDR blocks you can create an exemption by entering the IP address for it here"
}

variable "nodes" {
  type        = number
  description = "Number of nomad client to create"
}

variable "instance_type" {
  type        = string
  description = "AWS Node type for instance. Must be amd64 linux type"
  default     = "t3a.2xlarge"
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
