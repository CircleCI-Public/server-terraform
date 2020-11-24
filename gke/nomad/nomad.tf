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

### LOCATION - Zone Data ###
data "google_compute_zones" "zones_available" {
  depends_on = [google_project_service.compute_service]
  status     = "UP"
}

locals {
  zone     = substr(strrev(var.project_loc), 1, 1) == "-" ? var.project_loc : data.google_compute_zones.zones_available.names[0]
  basename = var.namespace != "" ? "${var.basename}-${replace(var.namespace, "/.*-g/", "")}" : var.basename
}

## SERVICE ACCOUNT ###
resource "google_service_account" "nomad_service_account" {
  depends_on   = [google_project_service.iam_service]
  account_id   = "${local.basename}-nomad-sa"
  display_name = "${local.basename}-nomad-sa"
  description  = "${local.basename} service account for CircleCI Server Nomad component"
}
resource "google_project_iam_member" "nomad_member_compute_admin" {
  depends_on = [google_service_account.nomad_service_account]
  role       = "roles/compute.admin"
  member     = "serviceAccount:${google_service_account.nomad_service_account.email}"
}
resource "google_project_iam_member" "nomad_member_storage" {
  depends_on = [google_service_account.nomad_service_account]
  role       = "roles/storage.admin"
  member     = "serviceAccount:${google_service_account.nomad_service_account.email}"
}
resource "google_project_iam_member" "nomad_member_logging" {
  depends_on = [google_service_account.nomad_service_account]
  role       = "roles/logging.admin"
  member     = "serviceAccount:${google_service_account.nomad_service_account.email}"
}
resource "google_project_iam_member" "nomad_member_monitoring" {
  depends_on = [google_service_account.nomad_service_account]
  role       = "roles/monitoring.admin"
  member     = "serviceAccount:${google_service_account.nomad_service_account.email}"
}
resource "google_project_iam_member" "nomad_member_service_controller" {
  depends_on = [google_service_account.nomad_service_account]
  role       = "roles/servicemanagement.serviceController"
  member     = "serviceAccount:${google_service_account.nomad_service_account.email}"
}
resource "google_project_iam_member" "nomad_member_service_management" {
  depends_on = [google_service_account.nomad_service_account]
  role       = "roles/servicemanagement.admin"
  member     = "serviceAccount:${google_service_account.nomad_service_account.email}"
}

resource "google_compute_instance_template" "nomad_template" {
  # We've add this wait to ensure that 
  depends_on = [time_sleep.wait_120_seconds]

  name_prefix  = "${local.basename}-nomad-template"
  machine_type = "n1-standard-8"

  service_account {
    email  = google_service_account.nomad_service_account.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile(
    "${path.module}/../../shared/nomad-scripts/nomad-startup.sh.tpl",
    {
      basename       = local.basename
      cloud_provider = "GCP"
    }
  )

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-1604-lts"
    disk_size_gb = 500
    boot         = true
    auto_delete  = true
  }

  tags = ["ssh", "nomad"]

  network_interface {
    network = var.network_name
    access_config {}
  }

  lifecycle {
    create_before_destroy = true
  }
  labels = {
    circleci = true
  }

}

resource "google_compute_firewall" "nomad_ssh" {
  count       = var.ssh_enabled ? 1 : 0
  name        = "${local.basename}-nomad-ssh"
  description = "${local.basename} firewall rule for CircleCI Server Nomand component"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = var.ssh_allowed_cidr_blocks
  target_tags   = ["ssh", "nomad"]
  network       = var.network_name
}

resource "google_compute_instance_group_manager" "nomad_manager" {
  depends_on         = [google_compute_instance_template.nomad_template]
  name               = "${local.basename}-nomad-manager"
  base_instance_name = "${local.basename}-nomad-client"
  description        = "${local.basename} compute instance group manager for CircleCI Server Nomand component"
  zone               = local.zone
  target_size        = var.nomad_count

  version {
    instance_template = google_compute_instance_template.nomad_template.self_link
  }
}


resource "time_sleep" "wait_120_seconds" {
  create_duration = "120s"
}
