resource "google_service_account" "cluster_node" {
  account_id   = "${var.unique_name}-cluster-node"
  display_name = "${var.unique_name} CircleCI Server cluster node"
  description  = "${var.unique_name} service account for CircleCI Server cluster nodes"
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

resource "random_string" "role_suffix" {
  length  = 8
  special = false
}

locals {
  # NB: The random suffix added to the role is important to avoid role name
  # collisions caused by the slow soft-delete behaviour of roles in GCP. Learn
  # more here:
  # https://cloud.google.com/iam/docs/creating-custom-roles#deleting_a_custom_role
  role_names = {
    object_storage = "${var.unique_name}_object_storage_${random_string.role_suffix.result}"
    external_dns   = "${var.unique_name}_external_dns_${random_string.role_suffix.result}"
  }
}

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
resource "google_project_iam_custom_role" "object_storage" {
  # '-' characters are forbidden in role names
  role_id = replace(local.role_names.object_storage, "-", "_")
  title   = "Object storage permissions for CircleCI Server ${var.unique_name}"
  permissions = [
    # Needed for signing urls https://github.com/circleci/circle-storage/blob/master/README.md#gcp
    "iam.serviceAccounts.signBlob",
    
    # Bucket read-only credentials
    "storage.buckets.get",
    "storage.buckets.list",

    # Object read-write credentials
    "storage.objects.create",
    "storage.objects.get",
    "storage.objects.delete,
    "storage.objects.list",
    "storage.objects.update"
  ]
}

resource "google_project_iam_member" "object_storage" {
  role   = google_project_iam_custom_role.object_storage.id
  member = "serviceAccount:${google_service_account.cluster_node.email}"
  condition {
    title       = "Data Bucket Only"
    description = "Restrict access to data bucket only"
    expression  = <<-EOF
      (
        resource.type != 'storage.googleapis.com/Bucket' &&
        resource.type != 'storage.googleapis.com/Object'
      ) || resource.name.startsWith('projects/_/buckets/${var.unique_name}-data')
    EOF
  }
}
