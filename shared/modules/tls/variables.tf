variable "nomad_server_hostname" {
  type        = string
  description = "Hostname of the nomad server."
}

variable "nomad_server_port" {
  type        = number
  description = "Port that the nomad server endpoint listens on."
  default     = 4647
}

variable "nomad_server_dns_enable" {
  type        = bool
  description = "Whether to enable DNS for the nomad server."
  default     = false
}

variable "nomad_server_dns_name" {
  type        = string
  description = "DNS name of the nomad server."
}

