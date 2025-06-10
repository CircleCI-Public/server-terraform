variable "project_id" {
  type        = string
  description = "GCP project ID to deploy resources into. By default uses the data sourced GCP project ID."
  default     = ""
}

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

variable "nomad_server_hostname" {
  type        = string
  description = "Hostname of RPC service of Nomad control plane (e.g circleci.example.com)"
  validation {
    condition     = !can(regex(":", var.nomad_server_hostname))
    error_message = "Found ':' in hostname. Port cannot be specified."
  }
}


variable "blocked_cidrs" {
  type        = list(string)
  default     = []
  description = "List of CIDR blocks to block access to from inside nomad jobs"
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

variable "name" {
  type        = string
  default     = "nomad"
  description = "VM instance name for nomad client"
}

variable "machine_image_project" {
  type        = string
  description = "The project value used to retrieve the virtual machine image."
  default     = "ubuntu-os-cloud"
}

variable "machine_image_family" {
  type        = string
  description = "The family value used to retrieve the virtual machine image."
  default     = "ubuntu-2004-lts"
}

variable "nomad_version" {
  type        = string
  description = "The version of Nomad to install"
  default     = "latest"
}

variable "min_server_replicas" {
  type        = number
  default     = 3
  description = "Minimum number of nomad server when scaled down"
}

variable "max_server_replicas" {
  type        = number
  default     = 7
  description = "Max number of nomad server when scaled up"
}

variable "server_machine_type" {
  type        = string
  default     = "n2-standard-4" # Intel | 8vCPU | 32GiB
  description = "Instance type for nomad server"
}

variable "server_disk_type" {
  type        = string
  default     = "pd-ssd"
  description = "Root disk type. Can be 'pd-standard', 'pd-ssd', 'pd-balanced' or 'local-ssd'"
}

variable "server_disk_size_gb" {
  type        = number
  default     = 80
  description = "Size of the root disk for nomad clients in GB."
}

variable "tls_cert" {
  type        = string
  default     = ""
  description = "TLS certificate for nomad server"
}

variable "tls_ca" {
  type        = string
  default     = ""
  description = "TLS CA for nomad server"

}

variable "tls_key" {
  type        = string
  default     = ""
  description = "TLS key for nomad server"
}

variable "server_autoscaling_mode" {
  type        = string
  default     = "ON"
  description = <<-EOF
    Autoscaler mode. Can be
    - "ON": Autoscaler will scale up and down to reach cpu target and react to cron schedules
    - "OFF": Autoscaler will never scale up or down
    - "ONLY_UP": Autoscaler will only scale up (default)
    Warning: jobs may be interrupted on scale down. Only select "ON" if
    interruptions are acceptible for your use case.
  EOF
}

variable "server_autoscaling_schedules" {
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

variable "nomad_server_auto_scaler" {
  type        = bool
  default     = true
  description = "If true, terraform will create a service account to be used by nomad autoscaler."
}

variable "server_target_cpu_utilization" {
  type        = number
  default     = 0.8
  description = "Target CPU utilization to trigger autoscaling"
}

variable "server_retry_join" {
  description = "Retry join address for nomad server"
  type        = string
}

variable "nomad_server_lb_ip" {
  description = "IP address for the nomad server load balancer"
  type        = string
}

variable "health_check_timeout_sec" {
  description = "Nomad Server Heath Check Timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_interval_sec" {
  description = "Nomad Server Heath Check Frequency in seconds"
  type        = number
  default     = 30
}

variable "health_check_healthy_threshold" {
  description = "Number of health checks success in a row to determine healthy"
  type        = number
  default     = 2
}


variable "health_check_unhealthy_threshold" {
  description = "Number of health checks failure in a row to determine unhealthy"
  type        = number
  default     = 5
}

variable "enable_firewall_logging" {
  type        = bool
  default     = false
  description = "If true, terraform will enable firewall logging for nomad server"
}