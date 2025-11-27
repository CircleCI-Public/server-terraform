mock_provider "google" {
  mock_data "google_compute_subnetwork" {
    defaults = {
      name          = "default"
      ip_cidr_range = "10.138.0.0/20"
      region        = "us-central1"
      self_link     = "https://www.googleapis.com/compute/v1/projects/test-project/regions/us-central1/subnetworks/default"
    }
  }

  mock_data "google_compute_image" {
    defaults = {
      name   = "ubuntu-2204-jammy-v20231101"
      family = "ubuntu-2204-lts"
    }
  }

  mock_data "google_project" {
    defaults = {
      project_id = "test-project"
      name       = "test-project"
      number     = "123456789"
    }
  }

  mock_data "google_container_cluster" {
    defaults = {
      name              = "test-k8s-cluster"
      location          = "us-central1"
      subnetwork        = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
      cluster_ipv4_cidr = "10.0.0.0/14"
    }
  }

  override_data {
    target = data.google_container_cluster.k8s[0]
    values = {
      name              = "test-k8s-cluster"
      location          = "us-central1"
      subnetwork        = "projects/test-project/regions/us-central1/subnetworks/test-subnet"
      cluster_ipv4_cidr = "10.0.0.0/14"
    }
  }

  override_data {
    target = data.google_compute_subnetwork.k8s[0]
    values = {
      name          = "test-subnet"
      ip_cidr_range = "10.100.0.0/20"
      region        = "us-central1"
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
      self_link     = "https://www.googleapis.com/compute/v1/projects/test-project/regions/us-central1/subnetworks/default"
    }
  }

  override_resource {
    target = google_compute_address.nomad_server[0]
    values = {
      name    = "test-server-nomad-server-lb-ip"
      address = "10.138.0.10"
    }
  }

  override_resource {
    target = module.server[0].google_compute_firewall.nomad
    values = {
      name = "allow-nomad-client-traffic-circleci-server-test-server"
      allow = [
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
    target = module.server[0].google_compute_firewall.nomad-ssh[0]
    values = {
      name = "fw-test-server-allow-ssh"
      allow = [
        {
          protocol = "tcp"
          ports    = ["22"]
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

  override_resource {
    target = module.server[0].google_compute_region_backend_service.nomad
    values = {
      name                  = "test-server-nomad-backend-service"
      protocol              = "TCP"
      load_balancing_scheme = "EXTERNAL"
      timeout_sec           = 10
      port_name             = "nomad"
      region                = "us-central1"
    }
  }
}

run "test_server_networking" {
  command = plan
  variables {
    project_id                    = "test-project"
    region                        = "us-central1"
    zone                          = "us-central1-a"
    name                          = "test-server"
    deploy_nomad_server_instances = true
    nomad_server_hostname         = "nomad.example.com"
    k8s_cluster_name              = "test-k8s-cluster"
    k8s_cluster_location          = "us-central1"
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
    k8s_cluster_name              = "test-k8s-cluster"
    k8s_cluster_location          = "europe-west1"
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
    k8s_cluster_name              = "test-k8s-cluster"
    k8s_cluster_location          = "asia-southeast1"
  }

  assert {
    condition     = module.server[0].nomad_server_health_check.https_health_check[0].port == 4646
    error_message = "Server health check should use Nomad port 4646"
  }

  assert {
    condition     = module.server[0].nomad_server_health_check.https_health_check[0].request_path == "/v1/agent/health?type=server"
    error_message = "Server health check should use server health endpoint"
  }

  assert {
    condition     = module.server[0].nomad_server_health_check.https_health_check[0].response == "{\"server\":{\"message\":\"ok\",\"ok\":true}}"
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
    k8s_cluster_name              = "test-k8s-cluster"
    k8s_cluster_location          = "canada-central1"
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
    k8s_cluster_name              = "test-k8s-cluster"
    k8s_cluster_location          = "canada-central1"
  }

  assert {
    condition     = module.server[0].nomad_server_firewall.name == "test-server-circleci-allow-nomad-client-traffic-nomad-servers"
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
    k8s_cluster_name              = "test-k8s-cluster"
    k8s_cluster_location          = "canada-central1"
  }

  assert {
    condition     = module.server[0].nomad_server_firewall.log_config[0].metadata == "INCLUDE_ALL_METADATA"
    error_message = "Default firewall should have logging enabled"
  }
}