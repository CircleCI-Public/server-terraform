output "nomad_server_cert" {
  value = module.nomad_tls ? module.nomad_tls.nomad_server_cert : ""
}

output "nomad_server_key" {
  value = module.nomad_tls ? module.nomad_tls.nomad_server_key : ""
}

output "nomad_tls_ca" {
  value = module.nomad_tls ? module.nomad_tls.nomad_tls_ca : ""
}