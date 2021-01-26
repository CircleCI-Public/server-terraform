output "cluster_name" {
  value = module.eks-cluster.cluster_id
}

output "region" {
  value = var.aws_region
}

output "subnet" {
  value = local.vm_subnet
}

output "bastion_public_ip" {
  value       = var.enable_bastion ? aws_instance.bastion[0.0].public_ip : "bastion has been disabled"
  description = "The public IP of the bastion host for SSH"
}

output "vm_service_security_group" {
  value       = aws_security_group.eks_nomad_sg[0].id
  description = "Security group to be used when creating VMs"
}

output "nomad_server_cert" {
  value = module.nomad.nomad_server_cert
}

output "nomad_server_key" {
  value = module.nomad.nomad_server_key
}

output "nomad_tls_ca" {
  value = module.nomad.nomad_tls_ca
}
