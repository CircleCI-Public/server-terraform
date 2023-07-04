# GCP Nomad Clients

This is a simple Terraform module to create Nomad clients for your CircleCI
server application on Google Cloud Platform.

## Usage

A basic example is as simple as this:

```Terraform
provider "google-beta" {
  project = "<< GCP project id >>"
  region  = "<< GCP compute region to deploy nomad clients >>""
  zone    = "<< GCP compute zone to deploy nomad clients >>""
}

module "nomad_clients" {
  # We strongly recommend pinning the version using ref=<<release tag>> as is done here
  source = "git::https://github.com/CircleCI-Public/server-terraform.git//nomad-gcp?ref=4.0.0"

  zone            = "<< GCP compute zone to deploy nomad clients >>"
  region          = "<< GCP compute region to deploy nomad clients >>"
  network         = "default"
  server_endpoint = "<< Hostname of server installation >>"
  name            = "<< name prefix of nomad clients >>
}

output "module" {
  value = module.nomad_clients
}
```

There are more examples in the [examples](./examples/) directory.

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
| [google_workload_identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| assign\_public\_ip | Assign public IP | `bool` | `true` | no |
| autoscaling\_mode | Autoscaler mode. Can be<br>- "ON": Autoscaler will scale up and down to reach cpu target and react to cron schedules<br>- "OFF": Autoscaler will never scale up or down<br>- "ONLY\_UP": Autoscaler will only scale up (default)<br>Warning: jobs may be interrupted on scale down. Only select "ON" if<br>interruptions are acceptible for your use case. | `string` | `"ONLY_UP"` | no |
| autoscaling\_schedules | Autoscaler scaling schedules. Accepts the same arguments are documented<br>upstream here: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_autoscaler#scaling_schedules | <pre>list(object({<br>    name                  = string<br>    min_required_replicas = number<br>    schedule              = string<br>    time_zone             = string<br>    duration_sec          = number<br>    disabled              = bool<br>    description           = string<br>  }))</pre> | `[]` | no |
| blocked\_cidrs | List of CIDR blocks to block access to from inside nomad jobs | `list(string)` | `[]` | no |
| docker_network_cidr | CIDR block to use in Docker Network, Should not be same as subnetworks CIDR | `string` | `10.10.0.0/16` | no |
| disk\_size\_gb | Root disk size in GB | `number` | `300` | no |
| disk\_type | Root disk type. Can be 'pd-standard', 'pd-ssd', 'pd-balanced' or 'local-ssd' | `string` | `"pd-ssd"` | no |
| machine\_type | Instance type for nomad clients.  The machine type must be large enough to fit the [resource classes](https://circleci.com/docs/2.0/executor-types/#available-docker-resource-classes) required.  Choosing smaller instance types is an opportunity for cost savings. | `string` | `"n2d-standard-8"` | no |
| max\_replicas | Max number of nomad clients when scaled up | `number` | `4` | no |
| min\_replicas | Minimum number of nomad clients when scaled down | `number` | `1` | no |
| name | VM instance name for nomad client | `string` | `"nomad"` | no |
| network | Network to deploy nomad clients into. If you are using a shared vpc, provide the network endpoint rather than the name | `string` | `"default"` | no |
| subnetwork | Subnetwork to deploy nomad clients into. This is required if using custom subnets or a shared vpc. If you are using a shared vpc, provide the subnetwork endpoint rather than the name | `string` | `""` | for custom subnets and shared vpcs |
| nomad_auto_scaler | If true, terraform will generate a service account to be used by nomad-autoscaler which will manage scaling of your nomad cluster. The service account key will be output to the file `nomad-as-key.json`, generated in your current working directory | `bool` | `false` | no |
| preemptible | Whether or not to use preemptible nodes | `bool` | `false` | no |
| region | GCP region to deploy nomad clients into (e.g us-east1) | `string` | n/a | yes |
| retry\_with\_ssh\_allowed\_cidr\_blocks | List of source IP CIDR blocks that can use the 'retry with SSH' feature of CircleCI jobs | `list(string)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| server\_endpoint | Hostname of the server installation | `string` | n/a | yes |
| target\_cpu\_utilization | Target CPU utilization to trigger autoscaling | `number` | `0.5` | no |
| unsafe\_disable\_mtls | Disables mTLS between nomad client and servers. Compromises the authenticity and confidentiality of client-server communication. Should not be set to true in any production setting | `bool` | `false` | no |
| zone | GCP compute zone to deploy nomad clients into (e.g us-east1-a) | `string` | n/a | yes |
| enable_workload_identity | Enable nomad service account as gcp workload identity. Ensure Workload Identities are first enabled on your GKE cluster: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity | `bool` | `false` | no |
| k8s_namespace | k8s namespace where application is installed | `string` | `circleci-server` | Yes, if enable_workload_identity is true |
| machine_image_project | The project value used to retrieve the virtual machine image. | `string` | `ubuntu-os-cloud` | no |
| machine_image_family | The family value used to retrieve the virtual machine image. | `string` | `ubuntu-2004-lts` | no |

## Outputs

| Name | Description |
|------|-------------|
| nomad\_server\_cert | n/a |
| nomad\_server\_key | n/a |
| nomad\_tls\_ca | n/a |
| nomad\_server\_cert\_base64 | set this value for the `nomad.server.rpc.mTLS.certificate` key in the [CircleCI Server's Helm values.yaml](https://circleci.com/docs/server/installation/installation-reference/#all-values-yaml-options) |
| nomad\_server\_key\_base64 | set this value for the `nomad.server.rpc.mTLS.privateKey` key in the [CircleCI Server's Helm values.yaml](https://circleci.com/docs/server/installation/installation-reference/#all-values-yaml-options) |
| nomad\_tls\_ca\_base64 | set this value for the `nomad.server.rpc.mTLS.CACertificate` key in the [CircleCI Server's Helm values.yaml](https://circleci.com/docs/server/installation/installation-reference/#all-values-yaml-options) |

---

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~> 3.0 |
| <a name="provider_local"></a> [local](#provider\_local) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_tls"></a> [tls](#module\_tls) | ./../shared/modules/tls | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_autoscaler.nomad](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_autoscaler) | resource |
| [google_compute_firewall.default](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_firewall) | resource |
| [google_compute_instance_group_manager.nomad](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_instance_group_manager) | resource |
| [google_compute_instance_template.nomad](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_target_pool.nomad](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_target_pool) | resource |
| [google_project_iam_member.nomad_as_compute_autoscalers_get](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.nomad_as_work_identity](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.nomad_as_service_account](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.nomad_as_work_identity_k8s](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/service_account_iam_binding) | resource |
| [google_service_account_key.nomad-as-key](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/service_account_key) | resource |
| [local_file.nomad-as-key-file](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [google_compute_image.machine_image](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/data-sources/compute_image) | data source |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_add_server_join"></a> [add\_server\_join](#input\_add\_server\_join) | Includes the 'server\_join' block when setting up nomad clients. Should be disabled when the nomad server endpoint is not immediately known (eg, for dedicated nomad clients). | `bool` | `true` | no |
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Assign public IP | `bool` | `true` | no |
| <a name="input_autoscaling_mode"></a> [autoscaling\_mode](#input\_autoscaling\_mode) | Autoscaler mode. Can be<br>- "ON": Autoscaler will scale up and down to reach cpu target and react to cron schedules<br>- "OFF": Autoscaler will never scale up or down<br>- "ONLY\_UP": Autoscaler will only scale up (default)<br>Warning: jobs may be interrupted on scale down. Only select "ON" if<br>interruptions are acceptible for your use case. | `string` | `"ONLY_UP"` | no |
| <a name="input_autoscaling_schedules"></a> [autoscaling\_schedules](#input\_autoscaling\_schedules) | Autoscaler scaling schedules. Accepts the same arguments are documented<br>upstream here: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_autoscaler#scaling_schedules | <pre>list(object({<br>    name                  = string<br>    min_required_replicas = number<br>    schedule              = string<br>    time_zone             = string<br>    duration_sec          = number<br>    disabled              = bool<br>    description           = string<br>  }))</pre> | `[]` | no |
| <a name="input_blocked_cidrs"></a> [blocked\_cidrs](#input\_blocked\_cidrs) | List of CIDR blocks to block access to from inside nomad jobs | `list(string)` | `[]` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Size of the root disk for nomad clients in GB. | `number` | `300` | no |
| <a name="input_disk_type"></a> [disk\_type](#input\_disk\_type) | Root disk type. Can be 'pd-standard', 'pd-ssd', 'pd-balanced' or 'local-ssd' | `string` | `"pd-ssd"` | no |
| <a name="input_docker_network_cidr"></a> [docker\_network\_cidr](#input\_docker\_network\_cidr) | IP CIDR block to be used in docker networks when running job on nomad client.<br>This CIDR block should not be the same as your VPC CIDR block.<br>i.e - "10.10.0.0/16" or "172.32.0.0/16" or "192.168.0.0/16" | `string` | `"10.10.0.0/16"` | no |
| <a name="input_enable_workload_identity"></a> [enable\_workload\_identity](#input\_enable\_workload\_identity) | If true, Workload Identity will be used rather than static credentials. Ensure Workload Identities are first enabled on your GKE cluster: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity | `bool` | `false` | no |
| <a name="input_k8s_namespace"></a> [k8s\_namespace](#input\_k8s\_namespace) | If enable\_workload\_identity is true, provide application k8s namespace | `string` | `"circleci-server"` | no |
| <a name="input_machine_image_family"></a> [machine\_image\_family](#input\_machine\_image\_family) | The family value used to retrieve the virtual machine image. | `string` | `"ubuntu-2004-lts"` | no |
| <a name="input_machine_image_project"></a> [machine\_image\_project](#input\_machine\_image\_project) | The project value used to retrieve the virtual machine image. | `string` | `"ubuntu-os-cloud"` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | Instance type for nomad clients | `string` | `"n2-standard-8"` | no |
| <a name="input_max_replicas"></a> [max\_replicas](#input\_max\_replicas) | Max number of nomad clients when scaled up | `number` | `4` | no |
| <a name="input_min_replicas"></a> [min\_replicas](#input\_min\_replicas) | Minimum number of nomad clients when scaled down | `number` | `1` | no |
| <a name="input_name"></a> [name](#input\_name) | VM instance name for nomad client | `string` | `"nomad"` | no |
| <a name="input_network"></a> [network](#input\_network) | Network to deploy nomad clients into | `string` | `"default"` | no |
| <a name="input_nomad_auto_scaler"></a> [nomad\_auto\_scaler](#input\_nomad\_auto\_scaler) | If true, terraform will create a service account to be used by nomad autoscaler. | `bool` | `false` | no |
| <a name="input_nomad_server_hostname"></a> [nomad\_server\_hostname](#input\_nomad\_server\_hostname) | Hostname of RPC service of Nomad control plane (e.g circleci.example.com) | `string` | n/a | yes |
| <a name="input_nomad_server_port"></a> [nomad\_server\_port](#input\_nomad\_server\_port) | Port that the server endpoint listens on for nomad connections. | `number` | `4647` | no |
| <a name="input_preemptible"></a> [preemptible](#input\_preemptible) | Whether or not to use preemptible nodes | `bool` | `false` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID to deploy resources into. By default uses the data sourced GCP project ID. | `string` | `""` | no |
| <a name="input_region"></a> [region](#input\_region) | GCP region to deploy nomad clients into (e.g us-east1) | `string` | n/a | yes |
| <a name="input_retry_with_ssh_allowed_cidr_blocks"></a> [retry\_with\_ssh\_allowed\_cidr\_blocks](#input\_retry\_with\_ssh\_allowed\_cidr\_blocks) | List of source IP CIDR blocks that can use the 'retry with SSH' feature of CircleCI jobs | `list(string)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | Subnetwork to deploy nomad clients into. NB. This is required if using custom subnets | `string` | `""` | no |
| <a name="input_target_cpu_utilization"></a> [target\_cpu\_utilization](#input\_target\_cpu\_utilization) | Target CPU utilization to trigger autoscaling | `number` | `0.5` | no |
| <a name="input_unsafe_disable_mtls"></a> [unsafe\_disable\_mtls](#input\_unsafe\_disable\_mtls) | Disables mTLS between nomad client and servers. Compromises the authenticity and confidentiality of client-server communication. Should not be set to true in any production setting | `bool` | `false` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | GCP compute zone to deploy nomad clients into (e.g us-east1-a) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_managed_instance_group_name"></a> [managed\_instance\_group\_name](#output\_managed\_instance\_group\_name) | n/a |
| <a name="output_managed_instance_group_region"></a> [managed\_instance\_group\_region](#output\_managed\_instance\_group\_region) | n/a |
| <a name="output_managed_instance_group_type"></a> [managed\_instance\_group\_type](#output\_managed\_instance\_group\_type) | n/a |
| <a name="output_managed_instance_group_zone"></a> [managed\_instance\_group\_zone](#output\_managed\_instance\_group\_zone) | n/a |
| <a name="output_nomad_server_cert"></a> [nomad\_server\_cert](#output\_nomad\_server\_cert) | n/a |
| <a name="output_nomad_server_cert_base64"></a> [nomad\_server\_cert\_base64](#output\_nomad\_server\_cert\_base64) | set this value for the `nomad.server.rpc.mTLS.certificate` key in the CircleCI Server's Helm values.yaml |
| <a name="output_nomad_server_key"></a> [nomad\_server\_key](#output\_nomad\_server\_key) | n/a |
| <a name="output_nomad_server_key_base64"></a> [nomad\_server\_key\_base64](#output\_nomad\_server\_key\_base64) | set this value for the `nomad.server.rpc.mTLS.privateKey` key in the CircleCI Server's Helm values.yaml |
| <a name="output_nomad_tls_ca"></a> [nomad\_tls\_ca](#output\_nomad\_tls\_ca) | n/a |
| <a name="output_nomad_tls_ca_base64"></a> [nomad\_tls\_ca\_base64](#output\_nomad\_tls\_ca\_base64) | set this value for the `nomad.server.rpc.mTLS.CACertificate` key in the CircleCI Server's Helm values.yaml |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | n/a |
| <a name="output_service_account_key"></a> [service\_account\_key](#output\_service\_account\_key) | Base64 decoded service account key. |
| <a name="output_service_account_key_location"></a> [service\_account\_key\_location](#output\_service\_account\_key\_location) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
