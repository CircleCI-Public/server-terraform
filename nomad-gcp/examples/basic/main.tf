variable "project" {
  type    = string
  default = "nsmith-dev"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-c"
}

variable "network" {
  type    = string
  default = "default"
}

variable "server_endpoint" {
  type    = string
  default = "nomad.ns.sphereci.com:4647"
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
  server_endpoint = var.server_endpoint

  unsafe_disable_mtls    = false
  assign_public_ip       = true
  preemptible            = true
  target_cpu_utilization = 0.50

  blocked_cidrs = [
    "8.8.8.8/32",
  ]
}

output "module" {
  value = module.nomad
}
