resource "google_service_account" "cluster_node" {
  account_id   = "${var.unique_name}-cluster-node"
  display_name = "${var.unique_name} CircleCI Server cluster node"
  description  = "${var.unique_name} service account for CircleCI Server cluster nodes"
}

resource "random_string" "role_suffix" {
  length  = 8
  special = false
}

locals {
  # NB: The random suffix added to the role is important to avoid role name
  # collisions caused by the slow soft-delete behaviour of roles in GCP. Learn
  # more here:
  # https://cloud.google.com/iam/docs/creating-custom-roles#deleting_a_custom_role
  role_name = "${var.unique_name}_blob_signer_${random_string.role_suffix.result}"
}

resource "google_project_iam_custom_role" "blob_signer" {
  # '-' characters are forbidden in role names
  role_id     = replace(local.role_name, "-", "_")
  title       = "Blob signer for ${var.unique_name}"
  permissions = ["iam.serviceAccounts.signBlob"]
}

# GKE Minimal node permissions as per
# https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa 
resource "google_project_iam_member" "metrics_viewer" {
  role   = "roles/monitoring.viewer"
  member = "serviceAccount:${google_service_account.cluster_node.email}"
}

resource "google_project_iam_member" "metrics_writer" {
  role   = "roles/monitoring.metricWriter"
  member = "serviceAccount:${google_service_account.cluster_node.email}"
}

resource "google_project_iam_member" "log_writer" {
  role   = "roles/logging.logWriter"
  member = "serviceAccount:${google_service_account.cluster_node.email}"
}

# Note: The following permission would be better applied using "Workload
# Identity" in GKE but are applied in a broad fashion here for the time
# being. Details of Workload Identity here:
# https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity

# DNS permissions for external-dns
resource "google_project_iam_member" "dns_admin" {
  # TODO: Narrow this down
  role   = "roles/dns.admin"
  member = "serviceAccount:${google_service_account.cluster_node.email}"
}

# VM permissions for vm-service
resource "google_project_iam_member" "compute_admin" {
  # TODO: Narrow this down
  role   = "roles/compute.admin"
  member = "serviceAccount:${google_service_account.cluster_node.email}"
}

# Object storage for many many services
resource "google_project_iam_member" "storage_admin" {
  # TODO: Narrow this down
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.cluster_node.email}"
}

resource "google_project_iam_member" "blobsigner" {
  role   = google_project_iam_custom_role.blob_signer.id
  member = "serviceAccount:${google_service_account.cluster_node.email}"
}
