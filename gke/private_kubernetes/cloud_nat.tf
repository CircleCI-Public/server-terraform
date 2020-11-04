
# create a router on host network to use with Cloud NAT
resource "google_compute_router" "router" {
  count   = var.enable_nat ? 1 : 0
  name    = "${var.unique_name}-cloud-router"
  network = var.network_uri
}

resource "google_compute_address" "address" {
  count = var.enable_nat ? 2 : 0
  name  = "${var.unique_name}-nat-external-address-${count.index}"
}

# implemented if var.subnets_to_nat list is populated.
resource "google_compute_router_nat" "advanced-nat-listedsubnets" {
  name                               = "${var.unique_name}-nat"
  count                              = var.enable_nat && length(var.subnets_to_nat) > 0 ? 1 : 0
  router                             = google_compute_router.router[0].name
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = google_compute_address.address.*.self_link
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  dynamic "subnetwork" {
    iterator = subnet
    for_each = var.subnets_to_nat
    content {
      name                    = subnet.value
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }
  }
}

# implemented if var.subnets_to_nat list is empty - defaults to subnet for current region
resource "google_compute_router_nat" "advanced-nat" {
  name                               = "${var.unique_name}-nat"
  count                              = var.enable_nat && length(var.subnets_to_nat) == 0 ? 1 : 0
  router                             = google_compute_router.router[0].name
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = google_compute_address.address.*.self_link
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = var.subnet_uri
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

}