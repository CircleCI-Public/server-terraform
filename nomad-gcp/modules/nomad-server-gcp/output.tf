output "nomad_server_nlb_ip" {
  value = google_compute_forwarding_rule.nomad.ip_address
}

output "nomad_server_instance_group_manager" {
  value = google_compute_instance_group_manager.nomad.name
}