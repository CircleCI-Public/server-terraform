
# these are necessary to get the kube liveness and readiness checks working
#
resource "google_compute_firewall" "allow_gcloud_health_checks" {
  name        = "allow-gcloud-health-checks-${var.unique_name}"
  description = "${var.unique_name} firewall rule for CircleCI Server cluster component"
  network     = var.network_uri
  priority    = 980

  allow { protocol = "tcp" }

  source_ranges = var.google_health_check_ips
  target_tags   = ["gke-node"]
}

# these are higher priority than both the default, and the rules for
# health checks and internal network(s)
#
resource "google_compute_firewall" "allowed_external_cidr_blocks" {
  count       = var.enable_bastion ? 0 : 1
  name        = "allowed-external-cidr-blocks-${var.unique_name}"
  description = "${var.unique_name} firewall rule for CircleCI Server cluster component"
  network     = var.network_uri
  priority    = 900

  allow { protocol = "icmp" }
  allow { protocol = "tcp" }
  allow { protocol = "udp" }

  source_ranges = var.allowed_external_cidr_blocks
}

resource "google_compute_firewall" "allow_vm_machine_ports" {
  name        = "allow-vm-machine-ports-${var.unique_name}"
  description = "${var.unique_name} firewall rule for CircleCI Server cluster component"
  network     = var.network_uri

  allow {
    protocol = "tcp"
    ports    = ["22", "2376", "54782"]
  }

  target_tags = ["docker-machine"]

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_bastion" {
  count       = var.enable_bastion ? 1 : 0
  name        = "allow-connections-to-${var.unique_name}-bastion"
  description = "${var.unique_name} firewall rule for CircleCI Server cluster component"
  network     = var.network_uri

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["bastion-host"]
  source_ranges = var.allowed_external_cidr_blocks
}
