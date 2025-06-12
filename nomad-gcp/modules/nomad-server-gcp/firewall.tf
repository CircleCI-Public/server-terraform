
resource "google_compute_firewall" "nomad" {
  name    = "fw-${var.name}-allow-nomad-client-traffic-circleci-server"
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

  dynamic "log_config" {
    for_each = var.enable_firewall_logging ? [1] : []
    content {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }

  source_ranges = [data.google_compute_subnetwork.nomad.ip_cidr_range] #tfsec:ignore:google-compute-no-public-ingress
}
