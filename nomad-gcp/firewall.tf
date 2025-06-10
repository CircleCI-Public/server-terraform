
resource "google_compute_firewall" "default" {
  name    = "fw-${var.name}-allow-retry-with-ssh-circleci-server"
  network = var.network
  project = length(regexall("projects/([^|]*)/regions", var.subnetwork)) > 0 ? regex("projects/([^|]*)/regions", var.subnetwork)[0] : null

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["64535-65535"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  source_ranges = var.retry_with_ssh_allowed_cidr_blocks #tfsec:ignore:google-compute-no-public-ingress
  target_tags   = local.tags
}


resource "google_compute_firewall" "nomad-traffic" {
  name    = "fw-${var.name}-allow-nomad-traffic-circleci-server"
  network = var.network
  project = length(regexall("projects/([^|]*)/regions", var.subnetwork)) > 0 ? regex("projects/([^|]*)/regions", var.subnetwork)[0] : null

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["4646-4648"]
  }

  allow {
    protocol = "udp"
    ports    = ["4646-4648"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  source_ranges = [data.google_compute_subnetwork.nomad.ip_cidr_range] #tfsec:ignore:google-compute-no-public-ingress
  target_tags   = local.tags
}

resource "google_compute_firewall" "nomad-ssh" {
  count = length(var.allowed_ips_nomad_ssh_access) > 0 ? 1 : 0

  name    = "fw-${var.name}-allow-ssh-into-nomad-clients-circleci-server"
  network = var.network
  project = length(regexall("projects/([^|]*)/regions", var.subnetwork)) > 0 ? regex("projects/([^|]*)/regions", var.subnetwork)[0] : null

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }

  # List of IPv4 CIDR ranges that are permitted to SSH into nomad clients
  source_ranges = var.allowed_ips_nomad_ssh_access #tfsec:ignore:google-compute-no-public-ingress
  target_tags   = local.tags
}