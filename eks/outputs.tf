output "cluster_name" {
  value = module.eks-cluster.cluster_id
}

output "region" {
  value = var.aws_region
}

output "subnet" {
  value = module.vpc.private_subnets[0]
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

locals {
  bastion_connect_command = var.bastion_key == "" ? "mssh ubuntu@${aws_instance.bastion[0.0].id}" : "ssh ubuntu@${aws_instance.bastion[0.0].public_ip}"
}

output "bastion_access_information" {
  value       = var.enable_bastion ? "To connect to your bastion run '${local.bastion_connect_command}'" : "bastion has been disabled"
  description = "Bastion host access information"
}

