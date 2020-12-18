# Backend configuration. Can't take variables.
terraform {
  required_providers {
    google      = "~> 3.51.0"
    google-beta = "~> 3.51.0"
  }
}

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

