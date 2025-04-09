terraform {
  required_providers {
    google = {
      version = "~> 3.0"
      // NOTE: This can be set to hashicorp/google once scaling_schedules are
      // out of beta on google_compute_autoscaler resources
      source = "hashicorp/google-beta"
    }
  }
}