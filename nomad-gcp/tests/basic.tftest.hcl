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

run "test_failure_handlers_do_not_exit_in_a_subshell" {
  variables {
    region                = "us-east1"
    zone                  = "us-east1-a"
    nomad_server_hostname = "example.com"
    name                  = "test-nomad"
  }

  assert {
    condition     = length(regexall("\\|\\|\\s*\\([^)]*\\bexit\\b", google_compute_instance_template.nomad.metadata_startup_script)) == 0
    error_message = "A failure handler runs exit inside ( ). That exit stops only the subshell, so the startup script continues. Use a brace group { ...; } instead."
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

run "test_cve_2026_98432_mitigation_enabled_by_default" {
  variables {
    region                = "us-east1"
    zone                  = "us-east1-a"
    nomad_server_hostname = "example.com"
    name                  = "test-nomad"
  }

  assert {
    condition     = can(regex("(?m)^mitigate_cve_2026_98432$", google_compute_instance_template.nomad.metadata_startup_script))
    error_message = "Startup script should call the CVE-2026-98432 mitigation by default"
  }

  assert {
    condition     = strcontains(google_compute_instance_template.nomad.metadata_startup_script, "mitigate_cve_2026_98432() {")
    error_message = "Startup script should define the CVE-2026-98432 mitigation it calls"
  }

  assert {
    condition = can(regex(
      "(?ms)^retry apt-get update$.*^mitigate_cve_2026_98432$",
      regex("(?s)^(.*?)\nif \\[ \"(?:true|false)\" [!=]= \"true\" \\]; then\n", google_compute_instance_template.nomad.metadata_startup_script)[0]
    ))
    error_message = "Startup script should call the CVE-2026-98432 mitigation after apt-get update and before the first Docker or Podman branch, so both runtime paths run it"
  }
}

run "test_cve_2026_98432_mitigation_disabled" {
  variables {
    region                           = "us-east1"
    zone                             = "us-east1-a"
    nomad_server_hostname            = "example.com"
    name                             = "test-nomad"
    enable_cve_2026_98432_mitigation = false
  }

  assert {
    condition     = !can(regex("(?m)^mitigate_cve_2026_98432$", google_compute_instance_template.nomad.metadata_startup_script))
    error_message = "Startup script should not call the CVE-2026-98432 mitigation when enable_cve_2026_98432_mitigation is false"
  }

  assert {
    condition     = !strcontains(google_compute_instance_template.nomad.metadata_startup_script, "mitigate_cve_2026_98432() {")
    error_message = "Startup script should not include the CVE-2026-98432 helper when enable_cve_2026_98432_mitigation is false"
  }
}
run "test_liveness_check_starts_after_nomad" {
  variables {
    region                = "us-east1"
    zone                  = "us-east1-a"
    nomad_server_hostname = "example.com"
    name                  = "test-nomad"
  }

  assert {
    condition     = strcontains(google_compute_instance_template.nomad.metadata_startup_script, "Description=Nomad client liveness check\n\tAfter=network.target nomad.service\n")
    error_message = "The client liveness unit should start after nomad.service, so that a check at boot does not find Nomad still starting"
  }
}

# The server module uses the hashicorp/google provider, which this file does
# not mock. This run thus renders the server template directly, and it checks
# the module calls in the .tf files.
run "test_server_cve_2026_98432_mitigation" {
  command = plan

  variables {
    region                = "us-east1"
    zone                  = "us-east1-a"
    nomad_server_hostname = "example.com"
    name                  = "test-nomad"
  }

  assert {
    condition = can(regex(
      "(?ms)^mitigate_cve_2026_98432\\(\\) \\{$.*^retry apt-get update$.*^mitigate_cve_2026_98432$.*^setup_liveness_check$.*^install_nomad ",
      templatefile("modules/nomad-server-gcp/templates/nomad-server-startup.sh.tpl", {
        nomad_version          = "1.11.3-1"
        blocked_cidrs          = []
        tls_cert               = "CERT"
        tls_key                = "KEY"
        tls_ca                 = "CA"
        max_replicas           = 3
        min_replicas           = 3
        server_retry_join      = "nomad.example.com"
        apt_helpers            = local.apt_helpers
        apt_retry_max_attempts = var.apt_retry_max_attempts
        cve_2026_98432_helpers = local.cve_2026_98432_helpers
        cve_2026_98432_enabled = true
        liveness_check_script  = ""
        set_unhealthy_script   = ""
      })
    ))
    error_message = "With the mitigation on, the server startup script should define the CVE-2026-98432 mitigation, and call it after apt-get update and before the liveness check and the Nomad install"
  }

  assert {
    condition = !strcontains(templatefile("modules/nomad-server-gcp/templates/nomad-server-startup.sh.tpl", {
      nomad_version          = "1.11.3-1"
      blocked_cidrs          = []
      tls_cert               = "CERT"
      tls_key                = "KEY"
      tls_ca                 = "CA"
      max_replicas           = 3
      min_replicas           = 3
      server_retry_join      = "nomad.example.com"
      apt_helpers            = local.apt_helpers
      apt_retry_max_attempts = var.apt_retry_max_attempts
      cve_2026_98432_helpers = local.cve_2026_98432_helpers
      cve_2026_98432_enabled = false
      liveness_check_script  = ""
      set_unhealthy_script   = ""
    }), "mitigate_cve_2026_98432")
    error_message = "With the mitigation off, the server startup script should not include or call the CVE-2026-98432 mitigation"
  }

  assert {
    condition = alltrue([
      can(regex("(?m)^\\s*cve_2026_98432_helpers\\s*=\\s*local\\.cve_2026_98432_helpers\\s*$", file("servers.tf"))),
      can(regex("(?m)^\\s*enable_cve_2026_98432_mitigation\\s*=\\s*var\\.enable_cve_2026_98432_mitigation\\s*$", file("servers.tf"))),
      can(regex("(?m)^\\s*cve_2026_98432_helpers\\s*=\\s*var\\.cve_2026_98432_helpers\\s*$", file("modules/nomad-server-gcp/server.tf"))),
      can(regex("(?m)^\\s*cve_2026_98432_enabled\\s*=\\s*var\\.enable_cve_2026_98432_mitigation\\s*$", file("modules/nomad-server-gcp/server.tf"))),
    ]) && var.enable_cve_2026_98432_mitigation
    error_message = "The root module and the server module should pass the CVE-2026-98432 helper and the flag to the server template unchanged"
  }

  assert {
    condition     = strcontains(file("modules/nomad-server-gcp/templates/nomad-server-startup.sh.tpl"), "Description=Nomad server liveness check\n\tAfter=network.target nomad.service\n") && var.enable_cve_2026_98432_mitigation
    error_message = "The server liveness unit should start after nomad.service, so that a check at boot does not find Nomad still starting"
  }
}
