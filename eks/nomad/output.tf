output "nomad_sg_id" {
  value = aws_security_group.nomad_sg[0].id
}

output "nomad_server_cert" {
  value = var.enable_mtls ? module.nomad_tls[0].nomad_server_cert : ""
}

output "nomad_server_key" {
  value = var.enable_mtls ? module.nomad_tls[0].nomad_server_key : ""
}

output "nomad_tls_ca" {
  value = var.enable_mtls ? module.nomad_tls[0].nomad_tls_ca : ""
}
