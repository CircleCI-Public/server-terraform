mock_provider "google" {
  mock_data "google_compute_subnetwork" {
    defaults = {
      name          = "default"
      ip_cidr_range = "10.138.0.0/20"
    }
  }

  mock_data "google_compute_image" {
    defaults = {
      name   = "ubuntu-2204-jammy-v20231101"
      family = "ubuntu-2204-lts"
    }
  }
}

run "test_firewall_configuration" {
  variables {
    region                = "us-west1"
    zone                  = "us-west1-a"
    nomad_server_hostname = "example.com"
    min_replicas          = 2
    max_replicas          = 8
    name                  = "test-nomad"
    machine_type          = "n2-standard-8"
  }

  assert {
    condition     = google_compute_firewall.default.name == "test-nomad-circleci-allow-retry-with-ssh"
    error_message = "Default firewall rule name should match expected pattern"
  }

  assert {
    condition = anytrue([
      for allow_block in google_compute_firewall.default.allow :
      contains(allow_block.ports, "64535-65535") if allow_block.protocol == "tcp"
    ])
    error_message = "Default firewall should allow retry-with-ssh port range 64535-65535"
  }

  assert {
    condition = anytrue([
      for allow_block in google_compute_firewall.nomad-traffic.allow :
      contains(allow_block.ports, "4646-4648") if allow_block.protocol == "tcp"
    ])
    error_message = "Nomad traffic firewall should allow Nomad TCP ports 4646-4648"
  }
}

run "test_default_subnetwork" {
  variables {
    region                = "us-east1"
    zone                  = "us-east1-a"
    nomad_server_hostname = "example.com"
    name                  = "test-nomad"
  }

  assert {
    condition     = data.google_compute_subnetwork.nomad.name == "default"
    error_message = "nomad subnetwork should be the default"
  }
}

run "test_when_subnetwork_is_a_self_link" {
  variables {
    region                = "us-west1"
    zone                  = "us-west1-a"
    nomad_server_hostname = "example.com"
    name                  = "test-nomad"
    subnetwork            = "https://www.googleapis.com/compute/v1/projects/my-parent-project/regions/us-west1/subnetworks/default"
  }

  assert {
    condition     = data.google_compute_subnetwork.nomad.self_link == "https://www.googleapis.com/compute/v1/projects/my-parent-project/regions/us-west1/subnetworks/default"
    error_message = "nomad subnetwork should be a self link"
  }
}

run "test_firewall_logging_configuration" {
  variables {
    region                       = "us-west1"
    zone                         = "us-west1-a"
    nomad_server_hostname        = "example.com"
    min_replicas                 = 2
    max_replicas                 = 8
    name                         = "test-nomad"
    machine_type                 = "n2-standard-8"
    enable_firewall_logging      = true
    allowed_ips_nomad_ssh_access = ["1.2.3.4/32", "5.6.7.8/32"]
  }

  assert {
    condition     = google_compute_firewall.default.log_config[0].metadata == "INCLUDE_ALL_METADATA"
    error_message = "Default firewall should have logging enabled"
  }

  assert {
    condition     = google_compute_firewall.nomad-traffic.log_config[0].metadata == "INCLUDE_ALL_METADATA"
    error_message = "nomad-traffic firewall should have logging enabled"
  }

  assert {
    condition     = google_compute_firewall.nomad-ssh[0].log_config[0].metadata == "INCLUDE_ALL_METADATA"
    error_message = "nomad-ssh firewall should have logging enabled"
  }
}

run "test_autoscaler_configuration" {
  variables {
    region                = "canada-central1"
    zone                  = "canada-central1-a"
    nomad_server_hostname = "example.com"
    min_replicas          = 3
    max_replicas          = 10
    name                  = "test-nomad"
    machine_type          = "n2-standard-8"
  }

  assert {
    condition     = google_compute_autoscaler.nomad.autoscaling_policy[0].min_replicas == 3
    error_message = "Autoscaler min replicas should be 3"
  }

  assert {
    condition     = google_compute_autoscaler.nomad.autoscaling_policy[0].max_replicas == 10
    error_message = "Autoscaler max replicas should be 10"
  }

  assert {
    condition     = google_compute_autoscaler.nomad.autoscaling_policy[0].cooldown_period == 120
    error_message = "Autoscaler should have 120 second cooldown period"
  }
}

run "test_health_check_configuration" {
  variables {
    region                = "canada-east1"
    zone                  = "canada-east1-a"
    nomad_server_hostname = "example.com"
    min_replicas          = 2
    max_replicas          = 8
    name                  = "test-nomad"
    machine_type          = "n2-standard-8"
  }

  assert {
    condition     = google_compute_health_check.nomad.http_health_check[0].port == 4646
    error_message = "Health check should use Nomad port 4646"
  }

  assert {
    condition     = google_compute_health_check.nomad.http_health_check[0].request_path == "/v1/agent/health?type=client"
    error_message = "Health check should use correct Nomad health endpoint"
  }
}

run "test_mtls_configuration" {
  variables {
    region                = "canada-east1"
    zone                  = "canada-east1-a"
    nomad_server_hostname = "example.com"
    min_replicas          = 2
    max_replicas          = 8
    name                  = "test-nomad"
    machine_type          = "n2-standard-8"
  }

  assert {
    condition     = module.tls.nomad_client_cert != ""
    error_message = "Nomad Client cert should not be empty"
  }

  assert {
    condition     = module.tls.nomad_client_key != ""
    error_message = "Nomad Client key should not be empty"
  }

  assert {
    condition     = module.tls.nomad_tls_ca != ""
    error_message = "Nomad CA should not be empty"
  }
}

run "test_startup_script_ubuntu_release" {
  variables {
    region                = "us-west1"
    zone                  = "us-west1-a"
    nomad_server_hostname = "example.com"
    name                  = "test-nomad"
  }

  assert {
    condition = alltrue([
      can(regex("(?m)^elif stat -fc %T /sys/fs/cgroup/ \\| grep -q tmpfs && command -v nomad >/dev/null 2>&1; then$", google_compute_instance_template.nomad.metadata_startup_script)),
      !strcontains(google_compute_instance_template.nomad.metadata_startup_script, "grep \"tmpfs\" && exit 0"),
    ])
    error_message = "The startup script should skip initialization only when cgroup v1 is active and nomad is installed"
  }

  assert {
    condition     = can(regex("(?m)^\\s*noble\\) DOCKER_VERSION=\"5:28\\.5\\.2-1~ubuntu\\.24\\.04~noble\" ;;$", google_compute_instance_template.nomad.metadata_startup_script))
    error_message = "Ubuntu 24.04 clients should install the noble docker-ce package"
  }

  assert {
    condition     = can(regex("(?m)^\\s*\\*\\)\\s+DOCKER_VERSION=\"5:28\\.5\\.2-1~ubuntu\\.22\\.04~jammy\" ;;$", google_compute_instance_template.nomad.metadata_startup_script))
    error_message = "Ubuntu 22.04 and other releases should keep the jammy docker-ce package"
  }

  assert {
    condition = alltrue([
      strcontains(google_compute_instance_template.nomad.metadata_startup_script, "docker-ce=\"$DOCKER_VERSION\""),
      strcontains(google_compute_instance_template.nomad.metadata_startup_script, "docker-ce-cli=\"$DOCKER_VERSION\""),
    ])
    error_message = "docker-ce and docker-ce-cli should install the version selected for the Ubuntu release"
  }

  assert {
    condition     = can(regex("(?m)^if stat -fc %T /sys/fs/cgroup/ \\| grep -q tmpfs; then\\n\\s*echo \"cgroup v1 is already active, no reboot needed\"\\nelse\\n\\s*revert_cgroups\\n\\s*reboot\\nfi$", google_compute_instance_template.nomad.metadata_startup_script))
    error_message = "The startup script should revert cgroups and reboot only when cgroup v2 is active"
  }
}

run "test_default_client_image" {
  command = plan

  variables {
    region                = "us-east1"
    zone                  = "us-east1-a"
    nomad_server_hostname = "example.com"
    name                  = "test-nomad"
  }

  assert {
    condition     = data.google_compute_image.machine_image.project == "circleci-images"
    error_message = "Clients should use the CircleCI Server Nomad image project by default"
  }

  assert {
    condition     = data.google_compute_image.machine_image.family == "circleci-server-nomad-image-2404"
    error_message = "Clients should use the Ubuntu 24.04 CircleCI Server Nomad image family by default"
  }
}

run "test_podman_switches_to_cgroup_v2" {
  command = plan
  variables {
    region                = "us-east1"
    zone                  = "us-east1-a"
    nomad_server_hostname = "example.com"
    name                  = "test-nomad"
    use_podman            = true
  }
  assert {
    condition     = can(regex("(?m)^if \\[ \"true\" == \"true\" \\]; then\n\\s*if stat -fc %T /sys/fs/cgroup/ \\| grep -q cgroup2fs && command -v nomad >/dev/null 2>&1; then\n\\s*echo \"cgroup v2 is active and Nomad is installed, skipping system initialization\"\n\\s*exit 0$", google_compute_instance_template.nomad.metadata_startup_script))
    error_message = "Podman clients should skip initialization only when cgroup v2 is active and nomad is installed"
  }
  assert {
    condition     = can(regex("enable_cgroups_v2\\(\\)\\s*\\{[^}]*for f in /etc/default/grub /etc/default/grub\\.d/\\*\\.cfg; do[^}]*s/ systemd\\.unified_cgroup_hierarchy=0//g' \"\\$f\" \\|\\| rc=1[^}]*update-grub \\|\\| rc=1\\s+return \\$rc", google_compute_instance_template.nomad.metadata_startup_script))
    error_message = "enable_cgroups_v2 should remove systemd.unified_cgroup_hierarchy=0 from /etc/default/grub and /etc/default/grub.d/*.cfg, run update-grub and return an error if a step fails"
  }
  assert {
    condition     = length(regexall("enable_cgroups_v2", google_compute_instance_template.nomad.metadata_startup_script)) == 2
    error_message = "The startup script should define enable_cgroups_v2 and call it once"
  }
  assert {
    condition     = can(regex("(?s)\nif \\[ \"true\" == \"true\" \\] && stat -fc %T /sys/fs/cgroup/ \\| grep -q tmpfs; then\n.*?\n\\s*cgroup_v2_marker=/var/lib/circleci/cgroup-v2-reboot\n\\s*if \\[ -e \"\\$cgroup_v2_marker\" \\]; then\n[^\n]*\n\\s*exit 1\n\\s*fi\n\\s*if ! enable_cgroups_v2 \\|\\| grep -q 'systemd\\.unified_cgroup_hierarchy=0' /boot/grub/grub\\.cfg; then\n[^\n]*\n\\s*exit 1\n\\s*fi\n\\s*mkdir -p /var/lib/circleci\n\\s*touch \"\\$cgroup_v2_marker\"\n[^\n]*\n\\s*reboot\n\\s*exit 0\n\\s*fi\n\\s*tune_io_scheduler\n", google_compute_instance_template.nomad.metadata_startup_script))
    error_message = "Podman clients on a cgroup v1 host should enable cgroup v2 and reboot once before the initialization starts, and stop if the switch fails"
  }
}

run "test_docker_does_not_switch_to_cgroup_v2" {
  command = plan
  variables {
    region                = "us-east1"
    zone                  = "us-east1-a"
    nomad_server_hostname = "example.com"
    name                  = "test-nomad"
  }
  assert {
    condition     = can(regex("(?m)^if \\[ \"false\" == \"true\" \\] && stat -fc %T /sys/fs/cgroup/ \\| grep -q tmpfs; then$", google_compute_instance_template.nomad.metadata_startup_script))
    error_message = "Docker clients should not run the cgroup v2 switch"
  }
}
