output "nomad_server_cert" {
  value = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_server_cert
}

output "nomad_server_key" {
  value = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_server_key
}

output "nomad_tls_ca" {
  value = var.unsafe_disable_mtls ? "" : module.tls[0].nomad_tls_ca
}
