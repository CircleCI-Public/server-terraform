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

variable "namespace" {
  default     = ""
  type        = string
  description = "(Optional) The namespace of your CircleCI deployment in an existing cluster"
}

variable "nomad_count" {
  type        = number
  default     = 1
  description = "The number of nomad clients to create"
}

variable "ssh_allowed_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "List of allowed source IP addresses that can access Nomad clients via SSH. Has no effect if `ssh_enabled` is not true."
}

variable "ssh_enabled" {
  type        = bool
  default     = false
  description = "If true, SSH access from the internet to Nomad clients is enabled. If enabled, use `gcloud compute ssh` to manage keys."
}

variable "nomad_sa_access" {
  type        = string
  default     = "allAuthenticatedUsers"
  description = "Who can use the Nomad ServiceAccount, e.g. for managing SSH keys on Nomad clients. Can be `user:{emailid}` for a single user, `group:{emailid}` for a Google group, or `allAuthenticatedUsers` to allow all authenticated users"
}

variable "network_name" {
  type        = string
  description = "Name of the GCP network to attach to nomad"
}

variable "enable_mtls" {
  type        = number
  default     = 1
  description = "MTLS support for Nomad traffic. Modifying this can be dangerous and is not recommended."
}