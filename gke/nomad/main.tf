provider "google" {
  region  = var.project_loc
  project = var.project_id
}

provider "google-beta" {
  region  = var.project_loc
  project = var.project_id
}
