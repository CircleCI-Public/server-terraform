# GCP Nomad Clients

This is a simple Terraform module to create Nomad clients for your CircleCI
server application on Google Cloud Platform.

## Usage

A basic example is as simple as this:

```Terraform
provider "google-beta" {
  project = "my-project"
  region  = "us-east1"
  zone    = "us-east1-a"
}

module "nomad" {
  # We strongly recommend pinning the version using ref=<<release tag>> as is done here
  source = "git::https://github.com/CircleCI-Public/server-terraform.git?//nomad-aws?ref=3.0.0"

  zone            = "us-east1-a"
  region          = "us-east1"
  network         = "default"
  server_endpoint = "nomad.example.com:4647"
}

output "module" {
  value = module.nomad
}
```

There are more examples in the `examples` directory.

## Requirements

| Name | Version |
|------|---------|
| google | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| google | ~> 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| tls | ./../shared/modules/tls |  |

## Resources

| Name |
|------|
| [google_compute_autoscaler](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_autoscaler) |
| [google_compute_firewall](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_firewall) |
| [google_compute_image](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/data-sources/compute_image) |
| [google_compute_instance_group_manager](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_instance_group_manager) |
| [google_compute_instance_template](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_instance_template) |
| [google_compute_target_pool](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_target_pool) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| assign\_public\_ip | Assign public IP | `bool` | `true` | no |
| autoscaling\_mode | Autoscaler mode. Can be<br>- "ON": Autoscaler will scale up and down to reach cpu target and react to cron schedules<br>- "OFF": Autoscaler will never scale up or down<br>- "ONLY\_UP": Autoscaler will only scale up (default)<br>Warning: jobs may be interrupted on scale down. Only select "ON" if<br>interruptions are acceptible for your use case. | `string` | `"ONLY_UP"` | no |
| autoscaling\_schedules | Autoscaler scaling schedules. Accepts the same arguments are documented<br>upstream here: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_autoscaler#scaling_schedules | <pre>list(object({<br>    name                  = string<br>    min_required_replicas = number<br>    schedule              = string<br>    time_zone             = string<br>    duration_sec          = number<br>    disabled              = bool<br>    description           = string<br>  }))</pre> | `[]` | no |
| blocked\_cidrs | List of CIDR blocks to block access to from inside nomad jobs | `list(string)` | `[]` | no |
| disk\_size\_gb | Root disk size in GB | `number` | `300` | no |
| disk\_type | Root disk type. Can be 'pd-standard', 'pd-ssd', 'pd-balanced' or 'local-ssd' | `string` | `"pd-ssd"` | no |
| machine\_type | Instance type for nomad clients | `string` | `"n2d-standard-8"` | no |
| max\_replicas | Max number of nomad clients when scaled up | `number` | `4` | no |
| min\_replicas | Minimum number of nomad clients when scaled down | `number` | `1` | no |
| name | VM instance name for nomad client | `string` | `"nomad"` | no |
| network | Network to deploy nomad clients into | `string` | `"default"` | no |
| preemptible | Whether or not to use preemptible nodes | `bool` | `false` | no |
| region | GCP region to deploy nomad clients into (e.g us-east1) | `string` | n/a | yes |
| retry\_with\_ssh\_allowed\_cidr\_blocks | List of source IP CIDR blocks that can use the 'retry with SSH' feature of CircleCI jobs | `list(string)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| server\_endpoint | Hostname:port of nomad control plane | `string` | n/a | yes |
| target\_cpu\_utilization | Target CPU utilization to trigger autoscaling | `number` | `0.5` | no |
| unsafe\_disable\_mtls | Disables mTLS between nomad client and servers. Compromises the authenticity and confidentiality of client-server communication. Should not be set to true in any production setting | `bool` | `false` | no |
| zone | GCP compute zone to deploy nomad clients into (e.g us-east1-a) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| nomad\_server\_cert | n/a |
| nomad\_server\_key | n/a |
| nomad\_tls\_ca | n/a |
