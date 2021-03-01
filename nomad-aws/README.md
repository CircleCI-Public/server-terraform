# AWS Nomad Clients

This is a simple Terraform module to create Nomad clients for your CircleCI
server application in AWS.

## Usage

A basic example is as simple as this:

```Terraform
terraform {
  required_version = ">= 0.14.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">=3.0.0"
    }
  }
}

provider "aws" {
  # Your region of choice here
  region = "us-west-1"
}

module "nomad_clients" {
  # We strongly recommend pinning the version using ref=<<release tag>> as is done here
  source = "git::https://github.com/CircleCI-Public/server-terraform.git?//nomad-aws?ref=3.0.0-RC7"

  # Number of nomad clients to run
  nodes = 4

  region = "<< Region you want to run nomad clients in >>"
  subnet = "<< ID of subnet you want to run nomad clients in >>"
  vpc_id = "<< ID of VPC you want to run nomad client in >>"

  server_endpoint = "<< hostname:port of nomad server >>"

  dns_server = "<< ip address of your VPC DNS server >>"
  blocked_cidrs = [
    "<< cidr blocks you’d like to block access to e.g 10.0.1.0/24 >>"
  ]
}

output "nomad_server_cert" {
  value = module.nomad_clients.nomad_server_cert
}

output "nomad_server_key" {
  value = module.nomad_clients.nomad_server_key
}

output "nomad_ca" {
  value = module.nomad_clients.nomad_tls_ca
}
```

There are more examples in the `examples` directory.

## Requirements

| Name | Version |
|------|---------|
| aws | ~> 3.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| basename | Name used as prefix for AWS resources | `string` | `""` | no |
| blocked\_cidrs | List of CIDR blocks to block access to from within jobs, e.g. your K8s nodes.<br>You won't want to block access to external VMs here.<br>It's okay when your dns\_server is within a blocked CIDR block, you can use var.dns\_server to create an exemption. | `list(string)` | n/a | yes |
| dns\_server | If the IP address of your VPC DNS server is within one of the blocked CIDR blocks you can create an exemption by entering the IP address for it here | `string` | n/a | yes |
| enable\_mtls | MTLS support for Nomad traffic. Modifying this can be dangerous and is not recommended. | `bool` | `true` | no |
| instance\_type | AWS Node type for instance. Must be amd64 linux type | `string` | `"t3a.2xlarge"` | no |
| nodes | Number of nomad client to create | `number` | n/a | yes |
| region | AWS Region | `string` | n/a | yes |
| security\_group\_id | ID for the security group for Nomad clients.<br>See security documentation for recommendations. | `list(string)` | `[]` | no |
| server\_endpoint | Domain and port of RPC service of Nomad control plane (e.g example.com:4647) | `string` | n/a | yes |
| ssh\_key | SSH Public key to access nomad nodes | `string` | `null` | no |
| subnet | Subnet ID | `string` | n/a | yes |
| vpc\_id | VPC ID of VPC used for Nomad resources | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| mtls\_enabled | n/a |
| nomad\_server\_cert | n/a |
| nomad\_server\_key | n/a |
| nomad\_tls\_ca | n/a |
