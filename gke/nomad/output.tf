output "nomad_server_cert" {
  value = length(module.nomad_tls) == 1 ? module.nomad_tls[0].nomad_server_cert : ""
}

output "nomad_server_key" {
  value = length(module.nomad_tls) == 1 ? module.nomad_tls[0].nomad_server_key : ""
}

output "nomad_tls_ca" {
  value = length(module.nomad_tls) == 1 ? module.nomad_tls[0].nomad_tls_ca : ""
}
