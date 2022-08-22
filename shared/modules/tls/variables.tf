variable "nomad_server_hostname" {
  type        = string
  description = "Hostname of the nomad server."
}

variable "nomad_server_port" {
  type        = number
  description = "Port that the nomad server endpoint listens on."
  default     = 4647
}
