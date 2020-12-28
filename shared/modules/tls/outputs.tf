output "nomad_server_cert" {
  value = tls_locally_signed_cert.nomad_server[0].cert_pem
}

output "nomad_server_key" {
  value = tls_private_key.nomad_server.private_key_pem
}

output "nomad_client_cert" {
  value = tls_locally_signed_cert.nomad_client[0].cert_pem
}

output "nomad_client_key" {
  value = tls_private_key.nomad_client.private_key_pem
}

output "nomad_tls_ca" {
  value = tls_self_signed_cert.nomad_ca[0].cert_pem
}
