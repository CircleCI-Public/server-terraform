### SERVICE ACCOUNT ###
data "google_project" "project" {
}

resource "google_service_account" "nomad_as_service_account" {
  count = var.nomad_auto_scaler ? 1 : 0

  project      = data.google_project.project.project_id
  account_id   = "${var.name}-nomad-autoscaler-sa"
  display_name = "${var.name}-nomad-autoscaler-sa"
  description  = "${var.name} service account for CircleCI Server cluster component"
}

resource "google_project_iam_member" "nomad_as_compute_autoscalers_get" {
  count  = var.nomad_auto_scaler ? 1 : 0
  role   = "roles/compute.admin"
  member = "serviceAccount:${google_service_account.nomad_as_service_account[0].email}"
}

resource "google_project_iam_member" "nomad_as_work_identity" {
  count  = var.nomad_auto_scaler && var.enable_workload_identity ? 1 : 0
  role   = "roles/iam.workloadIdentityUser"
  member = "serviceAccount:${google_service_account.nomad_as_service_account[0].email}"
}

resource "google_service_account_iam_binding" "nomad_as_work_identity_k8s" {
  count              = var.nomad_auto_scaler && var.enable_workload_identity ? 1 : 0
  service_account_id = google_service_account.nomad_as_service_account[0].name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${data.google_project.project.project_id}.svc.id.goog[${var.k8s_namespace}/nomad-autoscaler]",
  ]
}

resource "google_service_account_key" "nomad-as-key" {
  count              = var.nomad_auto_scaler && !var.enable_workload_identity ? 1 : 0
  service_account_id = google_service_account.nomad_as_service_account[0].name
}

resource "local_file" "nomad-as-key-file" {
  count    = var.nomad_auto_scaler && !var.enable_workload_identity ? 1 : 0
  content  = base64decode(google_service_account_key.nomad-as-key[0].private_key)
  filename = "${path.cwd}/nomad-as-key.json"
}