variable "nomad_server_hostname" {
  type        = string
  description = "Hostname of the nomad server."
}

variable "nomad_server_port" {
  type        = number
  description = "Port that the nomad server endpoint listens on."
  default     = 4647
}

variable "additional_dns_sans" {
  type        = list(string)
  description = "Additional DNS SANs to include in the Nomad server and client certificates."
  default     = []
}

variable "additional_ip_sans" {
  type        = list(string)
  description = "Additional IP SANs to include in the Nomad server and client certificates."
  default     = []
}
