module "nomad" {
  source = "./nomad"

  basename                = var.basename
  source_image            = var.nomad_source_image
  enable_mtls             = var.enable_mtls
  network_name            = google_compute_network.circleci_net.name
  nomad_count             = var.nomad_count
  nomad_sa_access         = var.nomad_sa_access
  project_id              = var.project_id
  project_loc             = var.project_loc
  ssh_allowed_cidr_blocks = var.allowed_cidr_blocks
  ssh_enabled             = var.nomad_ssh_enabled
}
