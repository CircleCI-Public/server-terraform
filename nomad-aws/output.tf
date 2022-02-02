output "mtls_enabled" {
  value = var.enable_mtls
}

output "nomad_server_cert" {
  value = var.enable_mtls ? module.nomad_tls[0].nomad_server_cert : ""
}

output "nomad_server_key" {
  value = var.enable_mtls ? nonsensitive(module.nomad_tls[0].nomad_server_key) : ""
}

output "nomad_tls_ca" {
  value = var.enable_mtls ? module.nomad_tls[0].nomad_tls_ca : ""
}

output "nomad_sg_id" {
  value = aws_security_group.nomad_sg.id
}

output "nomad_asg_user_access_key" {
  value = local.autoscaler_type == "user" ? aws_iam_access_key.nomad_asg_user[0].id : ""
}

output "nomad_asg_user_secret_key" {
  value = local.autoscaler_type == "user" ? aws_iam_access_key.nomad_asg_user[0].secret : ""
}

output "nomad_asg_name" {
  value = var.nomad_auto_scaler ? aws_autoscaling_group.clients_asg.name : ""
}

output "nomad_asg_arn" {
  value = var.nomad_auto_scaler ? aws_autoscaling_group.clients_asg.arn : ""
}

output "nomad_role" {
  value = local.autoscaler_type == "role" ? aws_iam_role.nomad_role[0].arn : ""
}