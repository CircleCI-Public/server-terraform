mock_provider "google" {
  mock_data "google_compute_subnetwork" {
    defaults = {
      name          = "default"
      ip_cidr_range = "10.138.0.0/20"
      region        = "us-central1"

    }
  }

  mock_data "google_compute_image" {
    defaults = {
      name   = "ubuntu-2204-jammy-v20231101"
      family = "ubuntu-2204-lts"
    }
  }

  override_data {
    target = module.server[0].data.google_compute_image.machine_image
    values = {
      name   = "ubuntu-2204-jammy-v20231101"
      family = "ubuntu-2204-lts"
    }
  }

  override_data {
    target = module.server[0].data.google_compute_subnetwork.nomad
    values = {
      name          = "default"
      ip_cidr_range = "10.138.0.0/20"
      region        = "us-central1"
    }
  }

  override_resource {
    target = module.server[0].google_compute_firewall.nomad
    values = {
      name = "allow-nomad-client-traffic-circleci-server-test-server"
      allow = [
        {
          protocol = "icmp"
          ports    = []
        },
        {
          protocol = "tcp"
          ports    = ["4646-4648"]
        },
        {
          protocol = "udp"
          ports    = ["4646-4648"]
        }
      ]
    }
  }

  override_resource {
    target = module.server[0].google_compute_health_check.nomad
    values = {
      name = "test-server-nomad-server-health-check"
      http_health_check = [{
        port         = 4646
        request_path = "/v1/agent/health?type=server"
        response     = "{\"server\":{\"message\":\"ok\",\"ok\":true}}"
      }]
    }
  }

  override_resource {
    target = module.server[0].google_compute_instance_template.nomad
    values = {
      name = "test-server-nomad-servers-template"
    }
  }

  override_resource {
    target = module.server[0].google_compute_target_pool.nomad
    values = {
      name = "test-server-nomad-server-pool"
    }
  }

  override_resource {
    target = module.server[0].google_compute_instance_group_manager.nomad
    values = {
      name               = "test-server-nomad-server-group"
      target_size        = 3
      base_instance_name = "test-server-nomad-server"
      auto_healing_policies = [{
        initial_delay_sec = 300
      }]
    }
  }

  override_resource {
    target = module.server[0].google_compute_autoscaler.nomad
    values = {
      name = "test-server-nomad-server-autoscaler"
      autoscaling_policy = [{
        min_replicas    = 5
        max_replicas    = 15
        cooldown_period = 120
        cpu_utilization = [{
          target = 0.7
        }]
      }]
    }
  }

  override_resource {
    target = module.server[0].google_compute_forwarding_rule.nomad
    values = {
      name                  = "test-server-nomad-server-forwarding-rule"
      port_range            = "4646-4648"
      ip_protocol           = "TCP"
      load_balancing_scheme = "EXTERNAL"
    }
  }
}

run "test_server_networking" {
  variables {
    region                        = "us-central1"
    zone                          = "us-central1-a"
    name                          = "test-server"
    deploy_nomad_server_instances = true
    nomad_server_hostname         = "nomad.example.com"
  }

  assert {
    condition     = var.deploy_nomad_server_instances == true
    error_message = "Nomad server should be enabled for this test"
  }

  assert {
    condition     = module.server[0].nomad_server_instance_group_manager != ""
    error_message = "Server instance group manager should be created"
  }
}

run "test_server_autoscaler_configuration" {
  variables {
    region                        = "europe-west1"
    zone                          = "europe-west1-b"
    name                          = "test-server"
    min_server_instances          = 5
    max_server_instances          = 15
    server_target_cpu_utilization = 0.7
    deploy_nomad_server_instances = true
    nomad_server_hostname         = "nomad.example.com"
  }

  assert {
    condition     = module.server[0].nomad_server_autoscaler.autoscaling_policy[0].min_replicas == 5
    error_message = "Server autoscaler min replicas should be 5"
  }

  assert {
    condition     = module.server[0].nomad_server_autoscaler.autoscaling_policy[0].max_replicas == 15
    error_message = "Server autoscaler max replicas should be 15"
  }

  assert {
    condition     = module.server[0].nomad_server_autoscaler.autoscaling_policy[0].cpu_utilization[0].target == 0.7
    error_message = "Server autoscaler CPU target should be 0.7"
  }
}

run "test_server_health_check_configuration" {
  variables {
    region                        = "asia-southeast1"
    zone                          = "asia-southeast1-a"
    name                          = "test-server"
    deploy_nomad_server_instances = true
    nomad_server_hostname         = "nomad.example.com"
  }

  assert {
    condition     = module.server[0].nomad_server_health_check.http_health_check[0].port == 4646
    error_message = "Server health check should use Nomad port 4646"
  }

  assert {
    condition     = module.server[0].nomad_server_health_check.http_health_check[0].request_path == "/v1/agent/health?type=server"
    error_message = "Server health check should use server health endpoint"
  }

  assert {
    condition     = module.server[0].nomad_server_health_check.http_health_check[0].response == "{\"server\":{\"message\":\"ok\",\"ok\":true}}"
    error_message = "Server health check should expect server response format"
  }
}

run "test_server_instance_group_configuration" {
  variables {
    region                        = "canada-central1"
    zone                          = "canada-central1-b"
    name                          = "test-server"
    deploy_nomad_server_instances = true
    nomad_server_hostname         = "nomad.example.com"
  }

  assert {
    condition     = module.server[0].nomad_server_instance_group_manager == "test-server-nomad-server-group"
    error_message = "Instance group manager name should match expected pattern"
  }
}

run "test_server_firewall_configuration" {
  variables {
    region                        = "canada-central1"
    zone                          = "canada-central1-b"
    name                          = "test-server"
    deploy_nomad_server_instances = true
    nomad_server_hostname         = "nomad.example.com"
  }

  assert {
    condition     = module.server[0].nomad_server_firewall.name == "fw-test-server-allow-nomad-client-traffic-circleci-server"
    error_message = "Instance group manager name should match expected pattern"
  }

  assert {
    condition = anytrue([
      for allow_block in module.server[0].nomad_server_firewall.allow :
      contains(allow_block.ports, "4646-4648") if allow_block.protocol == "tcp"
    ])
    error_message = "Nomad traffic firewall should allow Nomad TCP ports 4646-4648"
  }

  assert {
    condition = anytrue([
      for allow_block in module.server[0].nomad_server_firewall.allow :
      contains(allow_block.ports, "4646-4648") if allow_block.protocol == "udp"
    ])
    error_message = "Nomad traffic firewall should allow Nomad UDP port 4647"
  }
}



run "test_firewall_logging_configuration" {
  variables {
    region                        = "canada-central1"
    zone                          = "canada-central1-b"
    name                          = "test-server"
    deploy_nomad_server_instances = true
    nomad_server_hostname         = "nomad.example.com"
    enable_firewall_logging       = true
  }

  assert {
    condition     = module.server[0].nomad_server_firewall.log_config[0].metadata == "INCLUDE_ALL_METADATA"
    error_message = "Default firewall should have logging enabled"
  }
}