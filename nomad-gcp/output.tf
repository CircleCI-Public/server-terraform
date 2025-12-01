output "nomad_server_tls_cert_base64" {
  description = "set this value for the `nomad.server.rpc.mTLS.certificate` key in the CircleCI Server's Helm values.yaml"
  value       = var.deploy_nomad_server_instances ? "" : base64encode(module.tls.nomad_server_cert)
}

output "nomad_server_tls_key_base64" {
  description = "set this value for the `nomad.server.rpc.mTLS.privateKey` key in the CircleCI Server's Helm values.yaml"
  value       = var.deploy_nomad_server_instances ? "" : nonsensitive(base64encode(module.tls.nomad_server_key))
}

output "nomad_tls_ca_base64" {
  description = "set this value for the `nomad.server.rpc.mTLS.CACertificate` and `nomad.clients.mTLS.CACertificate` key in the CircleCI Server's Helm values.yaml"
  value       = base64encode(module.tls.nomad_tls_ca)
}

output "nomad_clients_cert_base64" {
  description = "set this value for the `nomad.clients.mTLS.certificate` key in the CircleCI Server's Helm values.yaml"
  value       = var.deploy_nomad_server_instances ? base64encode(module.tls.nomad_client_cert) : ""
}

output "nomad_clients_key_base64" {
  description = "set this value for the `nomad.clients.mTLS.privateKey` key in the CircleCI Server's Helm values.yaml"
  value       = var.deploy_nomad_server_instances ? nonsensitive(base64encode(module.tls.nomad_client_cert)) : ""
}

output "managed_instance_group_nomad_client" {
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

output "service_account_key" {
  value       = local.output_sa_key ? base64decode(google_service_account_key.nomad-as-key[0].private_key) : ""
  sensitive   = true
  description = "Base64 decoded service account key."
}

output "service_account_key_location" {
  value = var.enable_workload_identity ? "" : "${path.cwd}/nomad-as-key.json"
}

output "service_account_email" {
  value = var.nomad_auto_scaler ? google_service_account.nomad_as_service_account[0].email : ""
}

output "managed_instance_group_nomad_server" {
  value = var.deploy_nomad_server_instances ? module.server[0].nomad_server_instance_group_manager : ""
}

output "nomad_server_ip" {
  value = var.deploy_nomad_server_instances ? google_compute_address.nomad_server[0].address : ""
}