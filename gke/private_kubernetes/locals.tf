locals {

  default_node_tags = [
    "gke-node-natting",
    "gke-node"
  ]

  all_node_tags = flatten([local.default_node_tags, var.node_tags])

  default_labels = {
    "environment" = terraform.workspace
    "deployed-by" = "terraform"
    "circleci"    = true
  }

  all_labels = merge(local.default_labels, var.labels)

  zone   = substr(strrev(var.location), 1, 1) == "-" ? var.location : data.google_compute_zones.zones_available.names[0]
  region = substr(strrev(var.location), 1, 1) == "-" ? strrev(substr(strrev(var.location), 2, -1)) : var.location

}
