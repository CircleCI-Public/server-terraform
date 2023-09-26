locals {
  nomad_server_hostname_and_port = "${var.nomad_server_hostname}:${var.nomad_server_port}"
}

module "tls" {
  source                = "./../shared/modules/tls"
  nomad_server_hostname = var.nomad_server_hostname
  nomad_server_port     = var.nomad_server_port
  count                 = var.unsafe_disable_mtls ? 0 : 1
}

resource "google_compute_autoscaler" "nomad" {
  name   = "${var.name}-nomad-group"
  zone   = var.zone
  target = google_compute_instance_group_manager.nomad.id

  autoscaling_policy {
    max_replicas = var.max_replicas
    min_replicas = var.min_replicas
    mode         = var.autoscaling_mode

    # Wait 60s * 2 = 2 minutes for initialization before measuring CPU
    # utilization for autoscaling actions. This is the approximate boot
    # time of new nomad nodes as measured on a n2d-standard-8 VM.
    cooldown_period = 120

    cpu_utilization {
      target = var.target_cpu_utilization
    }

    dynamic "scaling_schedules" {
      for_each = var.autoscaling_schedules
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

resource "google_compute_instance_template" "nomad" {
  name_prefix    = "${var.name}-nomad-clients-"
  machine_type   = var.machine_type
  can_ip_forward = false

  tags = ["nomad", "circleci-server", "${var.name}-nomad-clients"]

  disk {
    source_image = data.google_compute_image.machine_image.self_link
    disk_type    = var.disk_type
    disk_size_gb = var.disk_size_gb
    boot         = true
    auto_delete  = true
  }

  metadata_startup_script = templatefile(
    "${path.module}/templates/nomad-startup.sh.tpl",
    {
      patched_nomad_version = var.patched_nomad_version
      add_server_join       = var.add_server_join ? var.add_server_join : ""
      nomad_server_endpoint = local.nomad_server_hostname_and_port
      blocked_cidrs         = var.blocked_cidrs
      client_tls_cert       = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_client_cert
      client_tls_key        = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_client_key
      tls_ca                = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_tls_ca
      docker_network_cidr   = var.docker_network_cidr
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

  scheduling {
    # Automatic restart and preemptible are mutually exclusive for
    # some reason
    automatic_restart = var.preemptible ? false : true
    preemptible       = var.preemptible
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_pool" "nomad" {
  name   = "${var.name}-nomad"
  region = var.region
}

resource "google_compute_instance_group_manager" "nomad" {
  name = "${var.name}-nomad"
  zone = var.zone

  version {
    instance_template = google_compute_instance_template.nomad.id
    name              = "primary"
  }

  target_pools       = [google_compute_target_pool.nomad.id]
  base_instance_name = "${var.name}-nomad"
}

data "google_compute_image" "machine_image" {
  family  = var.machine_image_family
  project = var.machine_image_project
}


resource "google_compute_firewall" "default" {
  name    = "allow-retry-with-ssh-circleci-server-${var.name}"
  network = var.network
  project = length(regexall("projects/([^|]*)/regions", var.subnetwork)) > 0 ? regex("projects/([^|]*)/regions", var.subnetwork)[0] : null

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["64535-65535"]
  }

  source_ranges = var.retry_with_ssh_allowed_cidr_blocks
  target_tags   = ["nomad", "circleci-server", var.name]
}
