locals {
  tags = ["nomad-server", "circleci-nomad-server", "circleci-${var.name}-nomad-servers", "nomad"]

}

resource "google_compute_autoscaler" "nomad" {
  name   = "${var.name}-nomad-server-autoscaler"
  zone   = var.zone
  target = google_compute_instance_group_manager.nomad.id

  autoscaling_policy {
    max_replicas = var.max_server_replicas
    min_replicas = var.min_server_replicas
    mode         = var.server_autoscaling_mode

    # Wait 60s * 2 = 2 minutes for initialization before measuring CPU
    # utilization for autoscaling actions. This is the approximate boot
    # time of new nomad nodes as measured on a n2d-standard-8 VM.
    cooldown_period = 120

    cpu_utilization {
      target = var.server_target_cpu_utilization
    }

    dynamic "scaling_schedules" {
      for_each = var.server_autoscaling_schedules
      content {
        name                  = scaling_schedules.value["name"]
        min_required_replicas = scaling_schedules.value["min_required_replicas"]
        schedule              = scaling_schedules.value["schedule"]
        time_zone             = scaling_schedules.value["time_zone"]
        duration_sec          = scaling_schedules.value["duration_sec"]
        disabled              = scaling_schedules.value["disabled"]
        description           = scaling_schedules.value["description"]
      }
    }
  }
}

resource "google_compute_health_check" "nomad" {
  name = "${var.name}-nomad-server-health-check"

  timeout_sec         = 5
  check_interval_sec  = 10
  healthy_threshold   = 4
  unhealthy_threshold = 5

  http_health_check {
    port         = "4646"
    host         = "127.0.0.1"
    request_path = "/v1/agent/health?type=server"
    proxy_header = "NONE"
    response     = "{\"server\":{\"message\":\"ok\",\"ok\":true}}"
  }
}

resource "google_compute_instance_template" "nomad" {
  name_prefix    = "${var.name}-nomad-servers-"
  machine_type   = var.machine_type
  can_ip_forward = false

  tags = local.tags

  labels = {
    app = "circleci-${var.name}-nomad-servers",
  }

  disk {
    source_image = data.google_compute_image.machine_image.self_link
    disk_type    = var.server_disk_type
    disk_size_gb = var.server_disk_size_gb
    boot         = true
    auto_delete  = true
  }

  metadata_startup_script = templatefile(
    "${path.module}/templates/nomad-server-startup.sh.tpl",
    {
      patched_nomad_version = var.patched_nomad_version
      blocked_cidrs         = var.blocked_cidrs
      tls_cert              = var.tls_cert
      tls_key               = var.tls_key
      tls_ca                = var.tls_ca
      max_replicas          = var.max_server_replicas
      min_replicas          = var.min_server_replicas
      server_retry_join     = var.server_retry_join
    }
  )

  network_interface {
    network    = var.subnetwork != "" ? null : var.network
    subnetwork = var.subnetwork != "" ? var.subnetwork : null

    dynamic "access_config" {
      # Content doesn't matter. We want a length 1 if true and 0 if false.
      for_each = var.assign_public_ip ? [0] : []
      content {
        # Empty content because empty access_config {} block
        # results in an ephemeral public IP.
      }
    }
  }

  shielded_instance_config {
    enable_secure_boot = true
  }


  lifecycle {
    create_before_destroy = true
  }

  service_account {
    # https://developers.google.com/identity/protocols/googlescopes
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/logging.write",
    ]
  }
  region = var.region
}

resource "google_compute_target_pool" "nomad" {
  name   = "${var.name}-nomad-server-pool"
  region = var.region
}

resource "google_compute_instance_group_manager" "nomad" {
  name = "${var.name}-nomad-server-group"
  zone = var.zone

  version {
    instance_template = google_compute_instance_template.nomad.id
    name              = "primary"
  }

  target_pools       = [google_compute_target_pool.nomad.id]
  target_size        = var.min_server_replicas
  base_instance_name = "${var.name}-nomad-server"

  auto_healing_policies {
    health_check      = google_compute_health_check.nomad.id
    initial_delay_sec = 300
  }
}

data "google_compute_image" "machine_image" {
  family  = var.machine_image_family
  project = var.machine_image_project
}


resource "google_compute_firewall" "nomad" {
  name    = "allow-connection-nomad-clients-to-nomad-server-for-${var.name}"
  network = var.network
  project = length(regexall("projects/([^|]*)/regions", var.subnetwork)) > 0 ? regex("projects/([^|]*)/regions", var.subnetwork)[0] : null

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["4646-4748"]
  }

  allow {
    protocol = "udp"
    ports    = ["4646-4748"]
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.retry_with_ssh_allowed_cidr_blocks #tfsec:ignore:google-compute-no-public-ingress
  target_tags   = local.tags
}


resource "google_compute_forwarding_rule" "nomad" {
  region                = var.region
  name                  = "${var.name}-nomad-server-forwarding-rule"
  target                = google_compute_target_pool.nomad.self_link
  load_balancing_scheme = "EXTERNAL"
  port_range            = "4646-4748"
  ip_protocol           = "TCP"
  # network               = var.network
  # subnetwork            = var.subnetwork
}
