
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

# very commonly the case, but an assumption that the internal network is 10/8
#
resource "google_compute_firewall" "allow_all_internal_network" {
  name        = "allow-all-internal-network-${var.unique_name}"
  description = "${var.unique_name} firewall rule for CircleCI Server cluster component"
  network     = var.network_uri
  priority    = 980

  allow { protocol = "icmp" }
  allow { protocol = "tcp" }
  allow { protocol = "udp" }

  source_ranges = ["10.0.0.0/8"]
}

# these are higher priority than both the default, and the rules for
# health checks and internal network(s)
#
resource "google_compute_firewall" "allowed_external_cidr_blocks" {
  count       = 1
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

resource "google_compute_firewall" "allow_rerun_with_ssh" {
  name        = "allow-rerun-with-ssh-ports-${var.unique_name}"
  description = "${var.unique_name} firewall rule for CircleCI Server cluster component"
  network     = var.network_uri
  priority    = 900

  allow {
    protocol = "tcp"
    ports    = ["64535-65535"]
  }

  target_tags = ["docker-machine", "nomad"]

  source_ranges = var.ssh_jobs_allowed_cidr_blocks
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
