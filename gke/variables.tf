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
  default     = true
  description = "By default, the Kubernetes endpoint is only accessible via the bastion host. Set to false if you want access via the public internet. You can use IP whitelisting using `allowed_cidr_blocks` to tighten access for both cases."
}

variable "private_vms" {
  type        = bool
  default     = true
  description = "By default, the VMs for the remote docker and machine executors are only accessible via the bastion host. Set to false if you want access via the public internet, in which case you will need to whitelist IPs using `allowed_cidr_blocks`"
}


variable "allowed_cidr_blocks" {
  type        = list(string)
  default     = []
  description = "This configures the allowable source IP blocks, depending on your configuration to your bastion host and/or Kubernetes cluster and/or Nomad clients and/or VMs"
}

variable "nomad_count" {
  type    = number
  default = 1
}

variable "nomad_ssh_enabled" {
  type        = bool
  default     = false
  description = "Enables SSH to Nomad clients. If enabled, use `gcloud compute ssh` to manage SSH keys. If you use a bastion host and a private endpoint, you can still connect to Nomad clients with this value set to `false` via the bastion host using their private IPs"
}

variable "nomad_sa_access" {
  type        = string
  default     = "allAuthenticatedUsers"
  description = "Who can use the Nomad ServiceAccount, e.g. for managing SSH keys on Nomad clients. Can be `user:{emailid}` for a single user, `group:{emailid}` for a Google group, or `allAuthenticatedUsers` to allow all authenticated users"
}
