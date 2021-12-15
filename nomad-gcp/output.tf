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

output "service_account_key_location" {
  value = "${path.cwd}/nomad-as-key.json"
}