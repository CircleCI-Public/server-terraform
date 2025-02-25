module "server" {
  source = "./modules/nomad-server-gcp"

  # count = var.nomad_server_enabled ? 1 : 0

  zone                          = var.zone
  region                        = var.region
  network                       = var.network
  subnetwork                    = var.subnetwork
  nomad_server_hostname         = var.nomad_server_hostname
  name                          = var.name
  project_id                    = var.project_id
  tls_cert                      = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_client_cert
  tls_key                       = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_client_key
  tls_ca                        = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_tls_ca
  min_server_replicas           = var.min_server_replicas
  max_server_replicas           = var.max_server_replicas
  nomad_server_auto_scaler      = var.nomad_server_auto_scaler
  server_autoscaling_mode       = var.server_autoscaling_mode
  server_autoscaling_schedules  = var.server_autoscaling_schedules
  server_target_cpu_utilization = var.server_target_cpu_utilization
  server_disk_size_gb           = var.server_disk_size_gb
  server_disk_type              = var.server_disk_type
  server_machine_type           = var.server_machine_type
  server_retry_join             = local.server_retry_join
}