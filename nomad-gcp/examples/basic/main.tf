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
  default = "nomad.example.com.com:4647"
}

provider "google-beta" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

module "nomad" {
  source = "./../../"

  zone            = var.zone
  region          = var.region
  network         = var.network
  subnetwork      = var.subnetwork
  server_endpoint = var.server_endpoint

  unsafe_disable_mtls    = false
  assign_public_ip       = true
  preemptible            = true
  target_cpu_utilization = 0.50
}

output "module" {
  value = module.nomad
}
