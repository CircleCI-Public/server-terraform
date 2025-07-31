output "nomad_server_cert" {
  value = module.nomad_tls.nomad_server_cert
}

output "nomad_server_key" {
  value = nonsensitive(module.nomad_tls.nomad_server_key)
}

output "nomad_tls_ca" {
  value = module.nomad_tls.nomad_tls_ca
}

output "nomad_server_cert_base64" {
  description = "set this value for the `nomad.server.rpc.mTLS.certificate` key in the CircleCI Server's Helm values.yaml"
  value       = base64encode(module.nomad_tls.nomad_server_cert)
}

output "nomad_server_key_base64" {
  description = "set this value for the `nomad.server.rpc.mTLS.privateKey` key in the CircleCI Server's Helm values.yaml"
  value       = nonsensitive(base64encode(module.nomad_tls.nomad_server_key))
}

output "nomad_tls_ca_base64" {
  description = "set this value for the `nomad.server.rpc.mTLS.CACertificate` key in the CircleCI Server's Helm values.yaml"
  value       = base64encode(module.nomad_tls.nomad_tls_ca)
}

output "nomad_sg_id" {
  value = aws_security_group.nomad_sg.id
}

output "nomad_asg_user_access_key" {
  value = local.autoscaler_type == "user" ? aws_iam_access_key.nomad_asg_user[0].id : ""
}

output "nomad_asg_user_secret_key" {
  sensitive = true
  value     = local.autoscaler_type == "user" ? aws_iam_access_key.nomad_asg_user[0].secret : ""
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

output "nomad_server_lb_arn" {
  value = var.deploy_nomad_server_instances ? module.server[0].lb_arn : ""
}

output "nomad_server_lb_url" {
  value = var.deploy_nomad_server_instances ? module.server[0].lb_url : ""
}

output "nomad_server_autoscaling_role" {
  value = var.deploy_nomad_server_instances ? module.server[0].role : ""
}

output "nomad_server_sg_id" {
  value = var.deploy_nomad_server_instances ? module.server[0].nomad_sg_id : ""
}

output "nomad_server_autoscaling_group_arn" {
  value = var.deploy_nomad_server_instances ? module.server[0].autoscaling_group_arn : ""
}


output "nomad_server_autoscaling_group_name" {
  value = var.deploy_nomad_server_instances ? module.server[0].autoscaling_group_name : ""
}