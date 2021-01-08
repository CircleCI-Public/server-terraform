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
  preemptible_nodes   = var.preemptible_k8s_nodes

  # Network configuration
  allowed_external_cidr_blocks   = var.allowed_cidr_blocks
  enable_nat                     = var.enable_nat
  enable_bastion                 = var.enable_bastion
  privileged_bastion             = var.privileged_bastion
  enable_istio                   = var.enable_istio
  enable_intranode_communication = var.enable_intranode_communication
  enable_dashboard               = var.enable_dashboard
  private_endpoint               = var.private_k8s_endpoint
  private_vms                    = var.private_vms

  network_uri = google_compute_network.circleci_net.self_link
  subnet_uri  = data.google_compute_subnetwork.circleci_net_subnet_data.self_link
}

resource "google_storage_bucket" "data_bucket" {
  name = "${var.basename}-data"
  labels = {
    circleci = true
  }
}
