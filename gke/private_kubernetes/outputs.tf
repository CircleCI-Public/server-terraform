output "cluster_name" {
  value = google_container_cluster.circleci_cluster.name
}

output "cluster_public_endpoint" {
  value = google_container_cluster.circleci_cluster.private_cluster_config[0].public_endpoint
}

output "bastion" {
  value = length(google_compute_instance.bastion)
}

output "bastion_name" {
  value = var.enable_bastion ? google_compute_instance.bastion[0].name : ""
}

output "region" {
  value = local.region
}

output "zone" {
  value = local.zone
}
