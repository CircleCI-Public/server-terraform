output "template" {
  value = google_compute_instance_template.nomad.metadata_startup_script
}