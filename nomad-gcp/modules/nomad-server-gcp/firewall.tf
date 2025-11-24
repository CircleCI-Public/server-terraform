
resource "google_compute_firewall" "nomad" {
  name    = "fw-${var.name}-circleci-allow-nomad-client-traffic-into-nomad-servers"
  network = var.network
  project = length(regexall("projects/([^|]*)/regions", var.subnetwork)) > 0 ? regex("projects/([^|]*)/regions", var.subnetwork)[0] : null

  allow {
    protocol = "tcp"
    ports    = ["4646-4648"]
  }

  allow {
    protocol = "udp"
    ports    = ["4646-4648"]
  }

  dynamic "log_config" {
    for_each = var.enable_firewall_logging ? [1] : []
    content {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }

  source_ranges = [data.google_compute_subnetwork.nomad.ip_cidr_range, "130.211.0.0/22", "35.191.0.0/16"] #tfsec:ignore:google-compute-no-public-ingress
  target_tags   = local.tags
}


resource "google_compute_firewall" "nomad-ssh" {
  count = length(var.allowed_ips_nomad_ssh_access) > 0 ? 1 : 0

  name    = "fw-${var.name}-circleci-allow-ssh-into-nomad-servers"
  network = var.network
  project = length(regexall("projects/([^|]*)/regions", var.subnetwork)) > 0 ? regex("projects/([^|]*)/regions", var.subnetwork)[0] : null


  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  dynamic "log_config" {
    for_each = var.enable_firewall_logging ? [1] : []
    content {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }

  # List of IPv4 CIDR ranges that are permitted to SSH into nomad clients
  source_ranges = var.allowed_ips_nomad_ssh_access #tfsec:ignore:google-compute-no-public-ingress
  target_tags   = local.tags
}
