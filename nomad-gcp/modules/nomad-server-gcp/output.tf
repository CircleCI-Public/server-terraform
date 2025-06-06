output "nomad_server_instance_group_manager" {
  value = google_compute_instance_group_manager.nomad.name
}

output "nomad_server_firewall" {
  value = google_compute_firewall.nomad
}

output "nomad_server_autoscaler" {
  value = google_compute_autoscaler.nomad
}

output "nomad_server_health_check" {
  value = google_compute_health_check.nomad
}

output "nomad_server_forwarding_rule" {
  value = google_compute_forwarding_rule.nomad
}
