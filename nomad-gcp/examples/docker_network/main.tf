###  If your VPC is falling in this CIDR range - "10.10.0.0/16"
###  You must need to use different CIDR for "docker_network_cidr" to avoid the IP overlapping issue
###

variable "project" {
  type    = string
  default = "example-project"
}

variable "region" {
  type    = string
  default = "us-west1"
}

variable "zone" {
  type    = string
  default = "us-west1-a"
}

variable "network" {
  type    = string
  default = "default"
  # if you are using a shared vpc, provide the network endpoint rather than the name. eg:
  # default = "https://www.googleapis.com/compute/v1/projects/<your-project>/global/networks/default"
}

variable "subnetwork" {
  type    = string
  default = "default"
  # if you are using a shared vpc, provide the network endpoint rather than the name. eg:
  # default = "https://www.googleapis.com/compute/v1/projects/<your-project>/regions/<your-region>/subnetworks/default"
}

variable "server_endpoint" {
  type    = string
  default = "nomad.example.com:4647"
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

variable "name" {
  type        = string
  default     = "nomad"
  description = "VM instance name for nomad client"
}

variable "enable_workload_identity" {
  type        = bool
  default     = false
  description = "If true, Workload Identity will be used rather than static credentials. Ensure Workload Identities are first enabled on your GKE cluster: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity"
}

variable "k8s_namespace" {
  type        = string
  default     = "circleci-server"
  description = "If enable_workload_identity is true, provide application k8s namespace"
}

variable "machine_type" {
  type    = string
  default = "n2-standard-8"
}

# You should use different IP CIDR (from VPC IP CIDR) for docker network within Nomad client to avoid IP overlapping issue
variable "docker_network_cidr" {
  type        = string
  description = <<-EOF
    IP CIDR block to be used in docker networks when running job on nomad client.
    This CIDR block should not be the same as your VPC CIDR block.
    i.e - "10.10.0.0/16" or "172.32.0.0/16" or "192.168.0.0/16"
    EOF
  default     = "10.10.0.0/16"
}

provider "google-beta" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

module "nomad" {
  # we are using latest code for gcp nomad client here
  source = "./../../"

  name                = var.name
  zone                = var.zone
  region              = var.region
  network             = var.network
  subnetwork          = var.subnetwork
  server_endpoint     = var.server_endpoint
  machine_type        = var.machine_type
  docker_network_cidr = var.docker_network_cidr

  unsafe_disable_mtls    = false
  assign_public_ip       = true
  preemptible            = true
  target_cpu_utilization = 0.50

  # Autoscaling for Managed Instance Group
  autoscaling_mode         = "ON"
  nomad_auto_scaler        = var.nomad_auto_scaler # If true, will generate a service account to be used by nomad-autoscaler. The is output in the file nomad-as-key.json
  max_replicas             = var.max_replicas      # Max and Min replica values should match the values intended to be used by nomad autoscaler in CircleCI Server
  min_replicas             = var.min_replicas
  enable_workload_identity = var.enable_workload_identity # If using GCP work identities rather than static keys in CircleCI Server
  k8s_namespace            = var.k8s_namespace            # If enable_workload_identity is true, provide k8s_namespace else leave as is
}

output "module" {
  value = module.nomad
}
