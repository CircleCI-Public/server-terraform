### SERVICE ACCOUNT ###
resource "google_service_account" "k8s_bastion_service_account" {
  account_id   = "${var.unique_name}-k8s-bastion-sa"
  display_name = "${var.unique_name}-k8s-bastion-sa"
  description  = "${var.unique_name} service account for CircleCI Server bastion host"
}

resource "google_project_iam_member" "k8s_bastion_container_admin" {
  count      = var.privileged_bastion ? 1 : 0
  depends_on = [google_service_account.k8s_bastion_service_account]
  role       = "roles/container.admin"
  member     = "serviceAccount:${google_service_account.k8s_bastion_service_account.email}"
}

resource "google_project_iam_member" "k8s_bastion_compute_admin" {
  count      = var.privileged_bastion ? 1 : 0
  depends_on = [google_service_account.k8s_bastion_service_account]
  role       = "roles/compute.admin"
  member     = "serviceAccount:${google_service_account.k8s_bastion_service_account.email}"
}

resource "google_project_iam_member" "k8s_bastion_dns_admin" {
  count      = var.privileged_bastion ? 1 : 0
  depends_on = [google_service_account.k8s_bastion_service_account]
  role       = "roles/dns.admin"
  member     = "serviceAccount:${google_service_account.k8s_bastion_service_account.email}"
}

resource "google_compute_instance" "bastion" {
  count                     = var.enable_bastion ? 1 : 0
  name                      = "${var.unique_name}-bastion"
  machine_type              = "custom-2-4096"
  zone                      = local.zone
  allow_stopping_for_update = true
  labels                    = local.all_labels
  tags                      = ["bastion-host"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  network_interface {
    network = var.network_uri

    access_config {}
  }

  service_account {
    email  = google_service_account.k8s_bastion_service_account.email
    scopes = ["cloud-platform"]
  }

  depends_on = [google_container_cluster.circleci_cluster]

  metadata_startup_script = join("\n", [
    "curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.20.0/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/bin/",
    "echo \"gcloud container clusters get-credentials --internal-ip --region ${var.location} ${var.unique_name}-k8s-cluster\" > update-kubeconfig && chmod +x update-kubeconfig && sudo mv ./update-kubeconfig /usr/bin/update-kubeconfig && update-kubeconfig",
    "curl -LO https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv3.8.8/kustomize_v3.8.8_linux_amd64.tar.gz && tar xzf ./kustomize_v3.8.8_linux_amd64.tar.gz && sudo mv ./kustomize /usr/bin/",
    "curl -LO https://github.com/replicatedhq/kots/releases/download/v1.25.2/kots_linux_amd64.tar.gz && tar xzf kots_linux_amd64.tar.gz && sudo mv ./kots /usr/bin/kubectl-kots",
    "curl -LO https://github.com/replicatedhq/troubleshoot/releases/download/v0.9.54/preflight_linux_amd64.tar.gz && tar xzf preflight_linux_amd64.tar.gz && sudo mv ./preflight /usr/bin/kubectl-preflight",
    "curl -LO https://github.com/replicatedhq/troubleshoot/releases/download/v0.9.55/support-bundle_linux_amd64.tar.gz && tar xzf support-bundle_linux_amd64.tar.gz && sudo mv ./support-bundle /usr/bin/kubectl-support_bundle"
  ])
}
