variable "zone" {
  type        = string
  description = "GCP compute zone to deploy nomad clients into (e.g us-east1-a)"
}

variable "region" {
  type        = string
  description = "GCP region to deploy nomad clients into (e.g us-east1)"
}

variable "network" {
  type        = string
  default     = "default"
  description = "Network to deploy nomad clients into"
}

variable "subnetwork" {
  type        = string
  default     = ""
  description = "Subnetwork to deploy nomad clients into. NB. This is required if using custom subnets"
}

variable "unsafe_disable_mtls" {
  type        = bool
  default     = false
  description = "Disables mTLS between nomad client and servers. Compromises the authenticity and confidentiality of client-server communication. Should not be set to true in any production setting"
}

variable "retry_with_ssh_allowed_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "List of source IP CIDR blocks that can use the 'retry with SSH' feature of CircleCI jobs"
}

variable "server_endpoint" {
  type        = string
  description = "Hostname:port of nomad control plane"
}

variable "blocked_cidrs" {
  type        = list(string)
  default     = []
  description = "List of CIDR blocks to block access to from inside nomad jobs"
}

variable "min_replicas" {
  type        = number
  default     = 1
  description = "Minimum number of nomad clients when scaled down"
}

variable "max_replicas" {
  type        = number
  default     = 4
  description = "Max number of nomad clients when scaled up"
}

variable "nomad_auto_scaler" {
  type        = bool
  default     = false
  description = "If true, terraform will create a service account to be used by nomad autoscaler."
}

variable "autoscaling_mode" {
  type        = string
  default     = "ONLY_UP"
  description = <<-EOF
    Autoscaler mode. Can be
    - "ON": Autoscaler will scale up and down to reach cpu target and react to cron schedules
    - "OFF": Autoscaler will never scale up or down
    - "ONLY_UP": Autoscaler will only scale up (default)
    Warning: jobs may be interrupted on scale down. Only select "ON" if
    interruptions are acceptible for your use case.
  EOF
}

variable "autoscaling_schedules" {
  type = list(object({
    name                  = string
    min_required_replicas = number
    schedule              = string
    time_zone             = string
    duration_sec          = number
    disabled              = bool
    description           = string
  }))
  default     = []
  description = <<-EOF
    Autoscaler scaling schedules. Accepts the same arguments are documented
    upstream here: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_autoscaler#scaling_schedules
  EOF
}

variable "target_cpu_utilization" {
  type        = number
  default     = 0.5
  description = "Target CPU utilization to trigger autoscaling"
}

variable "machine_type" {
  type        = string
  default     = "n2-standard-8" # Intel | 8vCPU | 32GiB
  description = "Instance type for nomad clients"
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "Assign public IP"
}

variable "preemptible" {
  type        = bool
  default     = false
  description = "Whether or not to use preemptible nodes"
}

variable "disk_type" {
  type        = string
  default     = "pd-ssd"
  description = "Root disk type. Can be 'pd-standard', 'pd-ssd', 'pd-balanced' or 'local-ssd'"
}

variable "disk_size_gb" {
  type        = number
  default     = 300
  description = "Root disk size in GB"
}

variable "name" {
  type        = string
  default     = "nomad"
  description = "VM instance name for nomad client"
}

variable "add_server_join" {
  type        = bool
  default     = true
  description = "Includes the 'server_join' block when setting up nomad clients. Should be disabled when the nomad server endpoint is not immediately known (eg, for dedicated nomad clients)."
}

variable "enable_workload_identity" {
  type        = bool
  default     = false
  description = "If true, Workload Identity will be used rather than static credentials"
}

variable "k8s_namespace" {
  type        = string
  default     = "circleci-server"
  description = "If enable_workload_identity is true, provide application k8s namespace"
}

variable "project" {
  type        = string
  description = "GCP Project"
}