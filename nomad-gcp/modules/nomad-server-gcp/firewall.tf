
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


# Only External type Load balancer is supported for target pool
resource "google_compute_forwarding_rule" "nomad" {
  region                = var.region
  name                  = "${var.name}-nomad-server-forwarding-rule"
  target                = google_compute_target_pool.nomad.self_link
  load_balancing_scheme = "EXTERNAL"
  port_range            = "4646-4748"
  ip_protocol           = "TCP"
  ip_address            = var.nomad_server_ip_address
}
