resource "google_compute_address" "nomad_server" {
  count = var.deploy_nomad_server_instances ? 1 : 0

  name         = "${var.name}-nomad-server-lb-ip"
  address_type = "EXTERNAL"
  region       = var.region
}

module "server" {
  source = "./modules/nomad-server-gcp"

  count = var.deploy_nomad_server_instances ? 1 : 0

  zone                             = var.zone
  region                           = var.region
  network                          = var.network
  subnetwork                       = var.subnetwork
  nomad_server_hostname            = var.nomad_server_hostname
  name                             = var.name
  project_id                       = var.project_id
  tls_cert                         = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_server_cert
  tls_key                          = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_server_key
  tls_ca                           = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_tls_ca
  min_server_instances             = var.min_server_instances
  max_server_instances             = var.max_server_instances
  nomad_server_auto_scaling        = var.nomad_server_auto_scaling
  server_autoscaling_mode          = var.server_autoscaling_mode
  server_autoscaling_schedules     = var.server_autoscaling_schedules
  server_target_cpu_utilization    = var.server_target_cpu_utilization
  server_disk_size_gb              = var.server_disk_size_gb
  server_disk_type                 = var.server_disk_type
  server_machine_type              = var.server_machine_type
  server_retry_join                = local.server_retry_join
  nomad_server_lb_ip               = google_compute_address.nomad_server[0].address
  health_check_timeout_sec         = var.health_check_timeout_sec
  health_check_interval_sec        = var.health_check_interval_sec
  health_check_healthy_threshold   = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold
  enable_firewall_logging          = var.enable_firewall_logging
}