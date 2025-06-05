
resource "google_compute_firewall" "nomad" {
  name    = "allow-nomad-client-traffic-circleci-server-${var.name}"
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

  source_ranges = [data.google_compute_subnetwork.nomad.ip_cidr_range] #tfsec:ignore:google-compute-no-public-ingress
  target_tags   = local.tags
}
