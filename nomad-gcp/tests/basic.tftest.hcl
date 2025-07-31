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
    condition     = google_compute_firewall.default.name == "fw-test-nomad-allow-retry-with-ssh-circleci-server"
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