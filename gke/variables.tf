variable "project_id" {
  type        = string
  description = "Name of existing project to create resources."
}

variable "project_loc" {
  type        = string
  default     = "us-west1"
  description = "Valid GKE location."
}

variable "force_destroy" {
  type    = bool
  default = false
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
  default     = false
  description = "Include a bastion/jump server in deployment. You can restrict the range of IPs that can connect to the bastion using `allowed_cidr_blocks`"
}

variable "privileged_bastion" {
  type        = bool
  default     = false
  description = "Grants container and compute admin access to the bastion Service Account. Set only to true if you understand the security implications of doing this"
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

variable "private_k8s_endpoint" {
  type        = bool
  default     = false
  description = "Setting this to true will disable access to the k8s API via the public internet. You will need a bastion or VPN to operate the k8s cluster"
}


variable "preemptible_k8s_nodes" {
  type        = bool
  default     = false
  description = "Use preemptible nodes for cluster. Keeps cost low for development or proof of concept cluster"
}

variable "private_vms" {
  type        = bool
  default     = false
  description = "Set to true to isolate VMs for `machine` and `remote_docker` executors from the public internet"
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  default     = []
  description = "This configures the allowable source IP blocks, depending on your configuration to your bastion host and/or Kubernetes cluster and/or Nomad clients and/or VMs"
}

variable "ssh_jobs_allowed_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "This configures the allowable source IP blocks that may ssh into jobs using the 'rerun job with SSH' functionality."
}

variable "nomad_count" {
  type    = number
  default = 1
}

variable "nomad_ssh_enabled" {
  type        = bool
  default     = true
  description = "Set to true this creates a firewall rule that allows TCP access on port 22 for the IPs whitelisted in `allowed_cidr_blocks` for SSH access. When set to false, SSH access is still possible by using a VPN or bastion host."
}

variable "nomad_sa_access" {
  type        = string
  default     = "allAuthenticatedUsers"
  description = "Who can use the Nomad ServiceAccount, e.g. for managing SSH keys on Nomad clients. Can be `user:{emailid}` for a single user, `group:{emailid}` for a Google group, or `allAuthenticatedUsers` to allow all authenticated users"
}

variable "enable_mtls" {
  type        = bool
  default     = true
  description = "mTLS support for Nomad traffic. Modifying this can be dangerous and is not recommended."
}

variable "nomad_source_image" {
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2004-lts"
  description = "The base OS image used by the Nomad clients."
}
