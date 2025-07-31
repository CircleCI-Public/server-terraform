provider "google-beta" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

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

variable "nomad_server_hostname" {
  type    = string
  default = "example.com"
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

variable "name" {
  type        = string
  default     = "nomad"
  description = "VM instance name for nomad client"
}

variable "machine_type" {
  type    = string
  default = "n2-standard-8"
}


module "nomad" {
  # we are using latest code for gcp nomad client here
  source = "./../../"

  name                  = var.name
  zone                  = var.zone
  region                = var.region
  network               = var.network
  subnetwork            = var.subnetwork
  nomad_server_hostname = var.nomad_server_hostname
  machine_type          = var.machine_type
  project_id            = var.project

  assign_public_ip       = true
  preemptible            = true
  target_cpu_utilization = 0.50

  # Autoscaling for Managed Instance Group
  autoscaling_mode = "ON"
  max_replicas     = var.max_replicas
  min_replicas     = var.min_replicas

  deploy_nomad_server_instances = true
  max_server_instances          = 5
  min_server_instances          = 3
  server_disk_size_gb           = 50
  server_target_cpu_utilization = 0.8
}

output "module" {
  value = module.nomad
}
