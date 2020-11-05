resource "google_dns_managed_zone" "internal_dns" {
  depends_on  = [google_project_service.dns_service]
  dns_name    = "${var.unique_name}.circleci.internal."
  name        = "${var.unique_name}-internal"
  description = "${var.unique_name} CircleCI Server DNS"

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = var.network_uri
    }
  }

  # force_destroy cascades deletion of this zone to delete all the DNS records
  # it contains as well.
  force_destroy = true
}
