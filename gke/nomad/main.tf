# Provider with service account credentials
provider "google" {
  region  = var.project_loc
  project = var.project_id
}

# Provider with service account credentials
provider "google-beta" {
  region  = var.project_loc
  project = var.project_id
}
