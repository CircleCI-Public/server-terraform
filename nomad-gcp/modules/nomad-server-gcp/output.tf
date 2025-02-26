output "nomad_server_instance_group_manager" {
  value = google_compute_instance_group_manager.nomad.name
}