output "cluster" {
  value = "${module.kube_private_cluster.cluster_name} (${module.kube_private_cluster.cluster_public_endpoint})"
}

output "bastion" {
  value = module.kube_private_cluster.bastion > 0 ? module.kube_private_cluster.bastion_name : "Not created."
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
