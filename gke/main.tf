####################################################
#  EXAMPLE INSTANCE OF PRIVATE KUBE CLUSTER MODULE
####################################################

### NETWORK ###
resource "google_compute_network" "circleci_net" {
  name                    = "${var.basename}-net"
  auto_create_subnetworks = "true"
}


### NETWORK - Subnet Data ###
data "google_compute_subnetwork" "circleci_net_subnet_data" {
  name       = google_compute_network.circleci_net.name
  depends_on = [google_compute_network.circleci_net]
}

# GKE cluster settings
module "kube_private_cluster" {

  # General
  source      = "./private_kubernetes"
  unique_name = var.basename
  project_id  = var.project_id
  location    = var.project_loc
  labels = {
    circleci = true
  }
  node_tags = []

  # Node pool configuration
  nodes_machine_spec = var.node_spec
  node_min           = var.node_min
  node_max           = var.node_max
  node_pool_cpu_max  = var.node_pool_cpu_max
  node_pool_ram_max  = var.node_pool_ram_max
  initial_nodes      = var.initial_nodes
  node_auto_repair   = var.node_auto_repair
  node_auto_upgrade  = var.node_auto_upgrade

  # Network configuration
  allowed_external_cidr_blocks   = var.allowed_cidr_blocks
  enable_nat                     = var.enable_nat
  enable_bastion                 = var.enable_bastion
  enable_istio                   = var.enable_istio
  enable_intranode_communication = var.enable_intranode_communication
  enable_dashboard               = var.enable_dashboard

  network_uri = google_compute_network.circleci_net.self_link
  subnet_uri  = data.google_compute_subnetwork.circleci_net_subnet_data.self_link
}

module "nomad" {
  source                  = "./nomad"
  project_loc             = var.project_loc
  project_id              = var.project_id
  basename                = var.basename
  service_account         = var.service_account
  nomad_count             = var.nomad_count
  ssh_enabled             = var.nomad_ssh_enabled
  ssh_allowed_cidr_blocks = var.allowed_cidr_blocks
  network_name            = google_compute_network.circleci_net.name
}

resource "google_storage_bucket" "data_bucket" {
  name = "${var.basename}-data"
  labels = {
    circleci = true
  }
}


# Outputs 

output "cluster" {
  value = "${module.kube_private_cluster.cluster_name} (${module.kube_private_cluster.cluster_public_endpoint})"
}

output "bastion" {
  value = module.kube_private_cluster.bastion > 0 ? module.kube_private_cluster.bastion_name : "Not created."
}
