
variable "allowed_external_cidr_blocks" {
  type = list(any)
}

variable "ssh_jobs_allowed_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "This configures the allowable source IP blocks that may ssh into jobs using the 'rerun job with SSH' functionality."
}

variable "unique_name" {
  type = string
}

variable "project_id" {
  type = string
}

variable "nodes_machine_spec" {
  type    = string
  default = "custom-2-8192"
}

variable "node_min" {
  type    = number
  default = 1
}

variable "node_max" {
  type    = number
  default = 2
}

variable "node_pool_cpu_max" {
  type    = number
  default = 128
}

variable "node_pool_ram_max" {
  type    = number
  default = 1024
}

variable "node_auto_repair" {
  type    = bool
  default = false
}

variable "node_auto_upgrade" {
  type    = bool
  default = false
}

variable "initial_nodes" {
  type    = number
  default = 1
}

variable "enable_nat" {
  type    = bool
  default = false
}

variable "enable_bastion" {
  type    = bool
  default = false
}

variable "location" {
  type    = string
  default = ""
}

variable "master_address_range" {
  type    = string
  default = "172.16.0.0/28"
}

variable "enable_istio" {
  type    = bool
  default = false
}

variable "enable_intranode_communication" {
  type    = bool
  default = false
}

variable "enable_dashboard" {
  type    = bool
  default = true
}

variable "google_health_check_ips" {
  type    = list(string)
  default = ["209.85.204.0/22", "130.211.0.0/22", "35.191.0.0/16", "209.85.152.0/22"]
}

variable "node_tags" {
  type    = list(string)
  default = []
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "subnets_to_nat" {
  type    = list(string)
  default = []
}

variable "nomad_count" {
  type    = number
  default = 0
}

variable "network_uri" {
  type = string
}
variable "subnet_uri" {
  type = string
}

variable "private_endpoint" {
  type = bool
}

variable "private_vms" {
  type = bool
}

variable "privileged_bastion" {
  type = bool
}

variable "preemptible_nodes" {
  type        = bool
  default     = false
  description = "Use preemptible nodes for cluster. Keeps cost low for development or proof of concept cluster"
}

variable "gke_release_channel" {
  type = string
  default = "REGULAR"
  description = "The GKE release channel to subscribe to. Should be one of RAPID/REGULAR/STABLE"
}
