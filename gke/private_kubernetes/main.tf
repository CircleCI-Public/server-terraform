### REQUIRED SERVICE API ###
resource "google_project_service" "cloudresourcemanager_service" {
  project            = var.project_id
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "iam_service" {
  depends_on         = [google_project_service.cloudresourcemanager_service]
  project            = var.project_id
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "compute_service" {
  depends_on         = [google_project_service.cloudresourcemanager_service]
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "dns_service" {
  depends_on         = [google_project_service.cloudresourcemanager_service]
  project            = var.project_id
  service            = "dns.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "container_service" {
  depends_on = [google_project_service.cloudresourcemanager_service,
    google_project_service.iam_service,
  google_project_service.compute_service]
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

### LOCATION - Zone Data ###
data "google_compute_zones" "zones_available" {
  depends_on = [google_project_service.compute_service]
  status     = "UP"
}

### GKE VERSION ###
data "google_container_engine_versions" "gke" {
  provider = google
  location = var.location
}

### NODE POOL ###
resource "google_container_node_pool" "node_pool" {
  name     = "${var.unique_name}-node-pool"
  location = var.location
  cluster  = google_container_cluster.circleci_cluster.name

  version = data.google_container_engine_versions.gke.release_channel_default_version["REGULAR"]

  autoscaling {
    min_node_count = var.node_min
    max_node_count = var.node_max
  }

  initial_node_count = var.initial_nodes

  node_config {
    preemptible     = var.preemptible_nodes
    machine_type    = var.nodes_machine_spec
    service_account = google_service_account.cluster_node.email
    oauth_scopes    = ["cloud-platform"]

    tags   = local.all_node_tags
    labels = local.all_labels
  }

  management {
    auto_repair  = var.node_auto_repair
    auto_upgrade = var.node_auto_upgrade
  }
}


### GKE CLUSTER ###
locals {
  private_endpoint = var.enable_bastion ? true : var.private_endpoint
}

resource "google_container_cluster" "circleci_cluster" {
  depends_on  = [google_project_service.container_service]
  name        = "${var.unique_name}-k8s-cluster"
  description = "${var.unique_name} CircleCI Server GKE cluster component"
  location    = var.location
  provider    = google-beta

  min_master_version = data.google_container_engine_versions.gke.release_channel_default_version["REGULAR"]

  network = var.network_uri
  # subnetwork               = var.subnet_uri
  initial_node_count          = "1"
  remove_default_node_pool    = true
  logging_service             = "logging.googleapis.com/kubernetes"
  monitoring_service          = "monitoring.googleapis.com/kubernetes"
  enable_intranode_visibility = var.enable_intranode_communication

  private_cluster_config {
    master_ipv4_cidr_block  = var.master_address_range
    enable_private_nodes    = true
    enable_private_endpoint = local.private_endpoint
  }

  ip_allocation_policy {
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      iterator = block
      for_each = local.private_endpoint ? [] : var.allowed_external_cidr_blocks
      content {
        cidr_block   = block.value
        display_name = block.value
      }
    }
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    istio_config {
      disabled = var.enable_istio ? false : true
    }
    network_policy_config {
      disabled = false
    }
  }

  # Changes to the description of a GKE cluster cause it to be replaced (this
  # is a limitation of the GCP API for clusters). We ignore changes to this
  # field as this is almost never the desired outcome.
  lifecycle {
    ignore_changes = [description, ]
  }
}
