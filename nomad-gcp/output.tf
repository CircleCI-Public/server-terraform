# output "nomad_server_tls_cert" {
#   value = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_server_cert
# }

# output "nomad_server_tls_key" {
#   value = var.unsafe_disable_mtls ? "" : nonsensitive(module.tls[0].nomad_server_key)
# }

# output "nomad_tls_ca" {
#   value = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_tls_ca
# }

# output "nomad_server_tls_cert_base64" {
#   description = "set this value for the `nomad.server.rpc.mTLS.certificate` key in the CircleCI Server's Helm values.yaml"
#   value       = var.unsafe_disable_mtls ? "" : base64encode(module.tls[0].nomad_server_cert)
# }

# output "nomad_server_tls_key_base64" {
#   description = "set this value for the `nomad.server.rpc.mTLS.privateKey` key in the CircleCI Server's Helm values.yaml"
#   value       = var.unsafe_disable_mtls ? "" : nonsensitive(base64encode(module.tls[0].nomad_server_key))
# }

# output "nomad_tls_ca_base64" {
#   description = "set this value for the `nomad.server.rpc.mTLS.CACertificate` key in the CircleCI Server's Helm values.yaml"
#   value       = var.unsafe_disable_mtls ? "" : base64encode(module.tls[0].nomad_tls_ca)
# }

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

output "managed_instance_group_instances_nomad_server" {
  value = module.server.nomad_server_instance_group_manager
}

output "nomad_server_nlb" {
  value = module.server.nomad_server_nlb_ip
}