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

variable "service_account" {
  type        = string
  default     = null
  description = "Path to json file for service account that will deploy resources. If not specified will default to $GOOGLE_APPLICATION_CREDENTIALS"
}

variable "nomad_count" {
  type        = number
  default     = 1
  description = "The number of nomad clients to create"
}

variable "ssh_allowed_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "List of allowed source IP addresses that can access Nomad clients via SSH. Has no effict if `ssh_enabled` is not true."
}

variable "ssh_enabled" {
  type        = bool
  default     = false
  description = "If true, SSH access to Nomad clients is enabled. If enabled, use `gcloud compute ssh` to manage keys."
}

variable "network_name" {
  type        = string
  description = "Name of the GCP network to attach to nomad"
}
