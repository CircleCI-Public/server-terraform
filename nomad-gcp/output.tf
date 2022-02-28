output "nomad_server_cert" {
  value = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_server_cert
}

output "nomad_server_key" {
  value = var.unsafe_disable_mtls ? "" : nonsensitive(module.tls[0].nomad_server_key)
}

output "nomad_tls_ca" {
  value = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_tls_ca
}

output "managed_instance_group_name" {
  value = google_compute_instance_group_manager.nomad.name
}

output "managed_instance_group_type" {
  value = "zonal"
}

output "managed_instance_group_region" {
  value = google_compute_target_pool.nomad.region
}

output "managed_instance_group_zone" {
  value = google_compute_instance_group_manager.nomad.zone
}

output "service_account_key_location" {
  value = var.enable_workload_identity  ? "" : "${path.cwd}/nomad-as-key.json"
}

output "service_account_email" {
  value = var.nomad_auto_scaler  ? google_service_account.nomad_as_service_account[0].email : ""
}