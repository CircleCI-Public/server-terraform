# This creates self-signed certs to encrypt the traffic between Nomad server and clients
terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 2.2"
    }
  }
}


locals {
  cert_validity_period = 876600 # 100 years, basically doesn't expire
}

resource "tls_private_key" "nomad_ca" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "nomad_ca" {
  key_algorithm   = tls_private_key.nomad_ca.algorithm
  private_key_pem = tls_private_key.nomad_ca.private_key_pem

  subject {
    common_name         = "Nomad CircleCI CA"
    organization        = "CircleCI"
    organizational_unit = "Server"
    street_address      = ["201 Spear St", "#1200"]
    locality            = "San Francisco"
    province            = "CA"
    country             = "US"
    postal_code         = "94105"
  }

  validity_period_hours = local.cert_validity_period

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]

  is_ca_certificate = true
}

resource "tls_private_key" "nomad_client" {
  algorithm = "RSA"
}

resource "tls_cert_request" "nomad_client" {
  key_algorithm   = tls_private_key.nomad_client.algorithm
  private_key_pem = tls_private_key.nomad_client.private_key_pem

  subject {
    common_name  = var.nomad_server_endpoint
    organization = "nomad:client"
  }

  dns_names = [
    "client.global.nomad",
    "localhost",
  ]

  ip_addresses = [
    "127.0.0.1",
  ]
}

resource "tls_locally_signed_cert" "nomad_client" {
  cert_request_pem   = tls_cert_request.nomad_client.cert_request_pem
  ca_key_algorithm   = tls_private_key.nomad_ca.algorithm
  ca_private_key_pem = tls_private_key.nomad_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.nomad_ca.cert_pem

  validity_period_hours = local.cert_validity_period

  allowed_uses = [
    "client_auth",
    "digital_signature",
    "key_agreement",
    "key_encipherment",
    "server_auth",
  ]
}

resource "tls_private_key" "nomad_server" {
  algorithm = "RSA"
}

resource "tls_cert_request" "nomad_server" {
  key_algorithm   = tls_private_key.nomad_server.algorithm
  private_key_pem = tls_private_key.nomad_server.private_key_pem

  subject {
    common_name  = var.nomad_server_endpoint
    organization = "nomad:client"
  }

  dns_names = [
    "server.global.nomad",
    "localhost",
  ]

  ip_addresses = [
    "127.0.0.1",
  ]
}

resource "tls_locally_signed_cert" "nomad_server" {
  cert_request_pem   = tls_cert_request.nomad_server.cert_request_pem
  ca_key_algorithm   = tls_private_key.nomad_ca.algorithm
  ca_private_key_pem = tls_private_key.nomad_ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.nomad_ca.cert_pem

  validity_period_hours = local.cert_validity_period

  allowed_uses = [
    "client_auth",
    "digital_signature",
    "key_agreement",
    "key_encipherment",
    "server_auth",
  ]
}
