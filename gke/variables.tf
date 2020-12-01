variable "project_id" {
  type        = string
  description = "Name of existing project to create resources."
}

variable "project_loc" {
  type        = string
  default     = "us-west1"
  description = "Valid GKE location."
}

variable "basename" {
  type        = string
  description = "Name of deployment to be used as a base for naming resources."
}

variable "node_spec" {
  type        = string
  default     = "n1-standard-8"
  description = "Machine type/size for K8s worker nodes."
}

variable "node_min" {
  type        = number
  default     = 1
  description = "Minimum number of nodes at any given time for autoscaler."
}

variable "node_max" {
  type        = number
  default     = 9
  description = "Maximum number of allowed nodes for autoscaler."
}

variable "node_pool_cpu_max" {
  type        = number
  default     = 128
  description = "Maximum number of CPUs in a node pool before autoscaler stops (resource limit)."
}

variable "node_pool_ram_max" {
  type        = number
  default     = 1024
  description = "Maximum GBs of RAM in a node pool before autoscaler stops (resource limit)."
}

variable "node_auto_repair" {
  type        = bool
  default     = true
  description = "Auto repair nodes."
}

variable "node_auto_upgrade" {
  type        = bool
  default     = true
  description = "Auto upgrade nodes."
}

variable "initial_nodes" {
  type        = number
  default     = 1
  description = "Number of nodes per region at deployment."
}

variable "enable_nat" {
  type        = bool
  default     = true
  description = "Enable deployment of NAT rules."
}

variable "enable_bastion" {
  type        = bool
  default     = true
  description = "Include a bastion/jump server in deployment."
}

variable "enable_istio" {
  type        = bool
  default     = false
  description = "Enable Istio on cluster."
}

variable "enable_intranode_communication" {
  type        = bool
  default     = false
  description = "Enable intra-node communication."
}

variable "enable_dashboard" {
  type        = bool
  default     = false
  description = "Enable Kubernetes dashboard."
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "List of blocks allowed to access the kubernetes cluster. This list also limits access to Nomad clients if `nomad_ssh_enabled` is true."
}

variable "nomad_count" {
  type    = number
  default = 1
}

variable "nomad_ssh_enabled" {
  type        = bool
  default     = false
  description = "Enables SSH to Nomad clients. If enabled, use `gcloud compute ssh` to manage SSH keys"
}
