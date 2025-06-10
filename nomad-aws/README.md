# AWS Nomad Clients

This is a simple Terraform module to create Nomad clients for your CircleCI
server application in AWS.

## Usage

A basic example is as simple as this:

```Terraform
terraform {
  required_version = ">= 0.15.4"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~>3.0"
    }
  }
}

provider "aws" {
  # Your region of choice here
  region = "us-west-1"
}

module "nomad_clients" {
  # We strongly recommend pinning the version using ref=<<release tag>> as is done here
  source = "git::https://github.com/CircleCI-Public/server-terraform.git//nomad-aws?ref=4.0.0"

  # Number of nomad clients to run
  nodes = 4

  subnet = "<< ID of subnet you want to run nomad clients in >>"
  vpc_id = "<< ID of VPC you want to run nomad client in >>"

  nomad_server_hostname = "<< hostname of server installation >>"

  dns_server = "<< ip address of your VPC DNS server >>"
  blocked_cidrs = [
    "<< cidr blocks you’d like to block access to e.g 10.0.1.0/24 >>"
  ]

  instance_tags = {
    "vendor" = "circleci"
    "team"   = "sre"
  }
  nomad_auto_scaler = false # If true, terraform will generate an IAM user to be used by nomad-autoscaler in CircleCI Server.

  # enable_irsa input will allow K8s service account to use IAM roles, you have to replace REGION, ACCOUNT_ID, OIDC_ID and K8S_NAMESPACE with appropriate value
  # for more info, visit - https://docs.aws.amazon.com/eks/latest/userguide/associate-service-account-role.html
  enable_irsa = {}

  ssh_key = "<< public key to be placed on each nomad client >>"
  basename = "<< name prefix for nomad clients >>"

  enable_imdsv2 = "<< optional/required >>"
}

output "nomad" {
  value     = module.nomad_clients
  sensitive = true
}
```

There are more examples in the [examples](./examples/) directory.
- [Basic example](./examples/basic/main.tf)
- [IRSA example](./examples/irsa/main.tf)

---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5 |
| <a name="requirement_cloudinit"></a> [cloudinit](#requirement\_cloudinit) | >=2.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5 |
| <a name="provider_cloudinit"></a> [cloudinit](#provider\_cloudinit) | >=2.3 |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_nomad_tls"></a> [nomad\_tls](#module\_nomad\_tls) | ../shared/modules/tls | n/a |
| <a name="module_server"></a> [server](#module\_server) | ./modules/nomad-server-aws | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.clients_asg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_iam_access_key.nomad_asg_user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_instance_profile.nomad_client_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.describe_ec2_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.nomad_instance_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.nomad_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.attach_policy_to_existing_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.attach_policy_to_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_user.nomad_asg_user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy.nomad_asg_user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy) | resource |
| [aws_key_pair.ssh_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_launch_template.nomad_clients](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_security_group.nomad_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.nomad_traffic_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.ssh_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [random_string.key_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_ami.ubuntu_focal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_iam_policy_document.assume_ec2_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ec2_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_role.existing_nomad_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role) | data source |
| [aws_vpc.nomad](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |
| [cloudinit_config.nomad_user_data](https://registry.terraform.io/providers/hashicorp/cloudinit/latest/docs/data-sources/config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_addr_type"></a> [addr\_type](#input\_addr\_type) | What IP should the Nomad servers discover | `string` | `"private_v4"` | no |
| <a name="input_allow_ssh"></a> [allow\_ssh](#input\_allow\_ssh) | Enable SSH access inbound (true/false) | `bool` | `false` | no |
| <a name="input_allowed_ips_circleci_server_nomad_access"></a> [allowed\_ips\_circleci\_server\_nomad\_access](#input\_allowed\_ips\_circleci\_server\_nomad\_access) | List of IPv4 ranges that are permitted to access nomad nodes; used for circleci-server-to-nomad communication | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_allowed_ips_retry_ssh"></a> [allowed\_ips\_retry\_ssh](#input\_allowed\_ips\_retry\_ssh) | List of IPv4 ranges that are permitted to access nomad nodes for the retry-with-ssh feature | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | The AWS region | `string` | `""` | no |
| <a name="input_basename"></a> [basename](#input\_basename) | Name used as prefix for AWS resources | `string` | `""` | no |
| <a name="input_blocked_cidrs"></a> [blocked\_cidrs](#input\_blocked\_cidrs) | List of CIDR blocks to block access to from within jobs, e.g. your K8s nodes.<br/>You won't want to block access to external VMs here.<br/>It's okay when your dns\_server is within a blocked CIDR block, you can use var.dns\_server to create an exemption. | `list(string)` | n/a | yes |
| <a name="input_client_public_ip"></a> [client\_public\_ip](#input\_client\_public\_ip) | Should the Nomad Client EC2 instances have a public IP? | `bool` | `false` | no |
| <a name="input_deploy_nomad_server_instances"></a> [deploy\_nomad\_server\_instances](#input\_deploy\_nomad\_server\_instances) | When true, nomad server instances will be deploy along with nomad clients | `bool` | `false` | no |
| <a name="input_desired_server_instances"></a> [desired\_server\_instances](#input\_desired\_server\_instances) | Desired number of Nomad Server instances | `number` | `3` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | The volume size, in GB to each nomad client's /dev/sda1 disk. | `number` | `100` | no |
| <a name="input_dns_server"></a> [dns\_server](#input\_dns\_server) | If the IP address of your VPC DNS server is within one of the blocked CIDR blocks you can create an exemption by entering the IP address for it here | `string` | n/a | yes |
| <a name="input_docker_network_cidr"></a> [docker\_network\_cidr](#input\_docker\_network\_cidr) | IP CIDR to be used in docker networks when running job on nomad client.<br/>This CIDR block should not be the same as your VPC CIDR block.<br/>i.e - "10.10.0.0/16" or "172.32.0.0/16" or "192.168.0.0/16" | `string` | `"10.10.0.0/16"` | no |
| <a name="input_enable_imdsv2"></a> [enable\_imdsv2](#input\_enable\_imdsv2) | Enable or Disable IMDSv2 on Nomad clients. Optional or Required. This is only supported on, or after, CircleCI Server 4.6.0 | `string` | `"optional"` | no |
| <a name="input_enable_irsa"></a> [enable\_irsa](#input\_enable\_irsa) | If passed a valid OIDC MAP, terraform will create K8s Service Account Role to be used by nomad autoscaler. | `map(any)` | `{}` | no |
| <a name="input_enable_mtls"></a> [enable\_mtls](#input\_enable\_mtls) | MTLS support for Nomad traffic. Modifying this can be dangerous and is not recommended. | `bool` | `true` | no |
| <a name="input_instance_tags"></a> [instance\_tags](#input\_instance\_tags) | n/a | `map(string)` | <pre>{<br/>  "vendor": "circleci"<br/>}</pre> | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | AWS Node type for instance. Must be Intel linux type | `string` | `"t3.2xlarge"` | no |
| <a name="input_launch_template_version"></a> [launch\_template\_version](#input\_launch\_template\_version) | Specific version of the instance template | `string` | `"$Latest"` | no |
| <a name="input_machine_image_names"></a> [machine\_image\_names](#input\_machine\_image\_names) | Strings to filter image names for nomad virtual machine images. | `list(string)` | <pre>[<br/>  "CircleCIServerNomad*"<br/>]</pre> | no |
| <a name="input_machine_image_owners"></a> [machine\_image\_owners](#input\_machine\_image\_owners) | List of AWS account IDs that own the images to be used for nomad virtual machines. | `list(string)` | <pre>[<br/>  "833371238208",<br/>  "535726571669"<br/>]</pre> | no |
| <a name="input_max_nodes"></a> [max\_nodes](#input\_max\_nodes) | Maximum number of nomad clients to create. Must be greater than or equal to nodes | `number` | `5` | no |
| <a name="input_max_server_instances"></a> [max\_server\_instances](#input\_max\_server\_instances) | Maximum number of Nomad Server instances | `number` | `7` | no |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Desired Number of nomad clients to create | `number` | n/a | yes |
| <a name="input_nomad_auto_scaler"></a> [nomad\_auto\_scaler](#input\_nomad\_auto\_scaler) | If set to true, A Nomad User or A Role will be created based on enable\_irsa variable values | `bool` | `false` | no |
| <a name="input_nomad_server_hostname"></a> [nomad\_server\_hostname](#input\_nomad\_server\_hostname) | Hostname of RPC service of Nomad control plane (e.g circleci.example.com) | `string` | n/a | yes |
| <a name="input_nomad_server_port"></a> [nomad\_server\_port](#input\_nomad\_server\_port) | Port that the server endpoint listens on for nomad connections. | `number` | `4647` | no |
| <a name="input_nomad_version"></a> [nomad\_version](#input\_nomad\_version) | The version of Nomad to install | `string` | `"1.7.7-1"` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name of the role to add to the instance profile | `string` | `null` | no |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | ID for the security group for Nomad clients.<br/>See security documentation for recommendations. | `list(string)` | `[]` | no |
| <a name="input_server_disk_size_gb"></a> [server\_disk\_size\_gb](#input\_server\_disk\_size\_gb) | Disk size for nomad server instances | `number` | `20` | no |
| <a name="input_server_machine_type"></a> [server\_machine\_type](#input\_server\_machine\_type) | The instance type of the EC2 Nomad Servers. | `string` | `"m4.xlarge"` | no |
| <a name="input_server_public_ip"></a> [server\_public\_ip](#input\_server\_public\_ip) | Should the Nomad Server EC2 instances have a public IP? | `bool` | `false` | no |
| <a name="input_ssh_key"></a> [ssh\_key](#input\_ssh\_key) | SSH Public key to access nomad nodes. Both clients and servers when deployed | `string` | `null` | no |
| <a name="input_subnet"></a> [subnet](#input\_subnet) | Subnet ID | `string` | `""` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Subnet IDs | `list(string)` | <pre>[<br/>  ""<br/>]</pre> | no |
| <a name="input_tag_key_for_discover"></a> [tag\_key\_for\_discover](#input\_tag\_key\_for\_discover) | The tag key placed on each EC2 instance for Nomad Server discoverability. | `string` | `"identifier"` | no |
| <a name="input_tag_key_name_value"></a> [tag\_key\_name\_value](#input\_tag\_key\_name\_value) | Value fo the name you want to name the EC2 instance. | `string` | `"circleci-nomad-server"` | no |
| <a name="input_tag_value_for_discover"></a> [tag\_value\_for\_discover](#input\_tag\_value\_for\_discover) | The tag value placed on each EC2 instance for Nomad Server discoverability. | `string` | `"circleci-nomad-server-instance"` | no |
| <a name="input_volume_type"></a> [volume\_type](#input\_volume\_type) | The EBS volume type of the node. If gp3 is not available in your desired region, switch to gp2 | `string` | `"gp3"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID of VPC used for Nomad resources | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_mtls_enabled"></a> [mtls\_enabled](#output\_mtls\_enabled) | set this value for the `nomad.server.rpc.mTLS.enabled` key in the CircleCI Server's Helm values.yaml |
| <a name="output_nomad_asg_arn"></a> [nomad\_asg\_arn](#output\_nomad\_asg\_arn) | n/a |
| <a name="output_nomad_asg_name"></a> [nomad\_asg\_name](#output\_nomad\_asg\_name) | n/a |
| <a name="output_nomad_asg_user_access_key"></a> [nomad\_asg\_user\_access\_key](#output\_nomad\_asg\_user\_access\_key) | n/a |
| <a name="output_nomad_asg_user_secret_key"></a> [nomad\_asg\_user\_secret\_key](#output\_nomad\_asg\_user\_secret\_key) | n/a |
| <a name="output_nomad_role"></a> [nomad\_role](#output\_nomad\_role) | n/a |
| <a name="output_nomad_server_autoscaling_group_arn"></a> [nomad\_server\_autoscaling\_group\_arn](#output\_nomad\_server\_autoscaling\_group\_arn) | n/a |
| <a name="output_nomad_server_autoscaling_group_name"></a> [nomad\_server\_autoscaling\_group\_name](#output\_nomad\_server\_autoscaling\_group\_name) | n/a |
| <a name="output_nomad_server_autoscaling_role"></a> [nomad\_server\_autoscaling\_role](#output\_nomad\_server\_autoscaling\_role) | n/a |
| <a name="output_nomad_server_cert"></a> [nomad\_server\_cert](#output\_nomad\_server\_cert) | n/a |
| <a name="output_nomad_server_cert_base64"></a> [nomad\_server\_cert\_base64](#output\_nomad\_server\_cert\_base64) | set this value for the `nomad.server.rpc.mTLS.certificate` key in the CircleCI Server's Helm values.yaml |
| <a name="output_nomad_server_key"></a> [nomad\_server\_key](#output\_nomad\_server\_key) | n/a |
| <a name="output_nomad_server_key_base64"></a> [nomad\_server\_key\_base64](#output\_nomad\_server\_key\_base64) | set this value for the `nomad.server.rpc.mTLS.privateKey` key in the CircleCI Server's Helm values.yaml |
| <a name="output_nomad_server_lb_arn"></a> [nomad\_server\_lb\_arn](#output\_nomad\_server\_lb\_arn) | n/a |
| <a name="output_nomad_server_lb_url"></a> [nomad\_server\_lb\_url](#output\_nomad\_server\_lb\_url) | n/a |
| <a name="output_nomad_server_sg_id"></a> [nomad\_server\_sg\_id](#output\_nomad\_server\_sg\_id) | n/a |
| <a name="output_nomad_sg_id"></a> [nomad\_sg\_id](#output\_nomad\_sg\_id) | n/a |
| <a name="output_nomad_tls_ca"></a> [nomad\_tls\_ca](#output\_nomad\_tls\_ca) | n/a |
| <a name="output_nomad_tls_ca_base64"></a> [nomad\_tls\_ca\_base64](#output\_nomad\_tls\_ca\_base64) | set this value for the `nomad.server.rpc.mTLS.CACertificate` key in the CircleCI Server's Helm values.yaml |
| <a name="output_update_nomad_profile_role"></a> [update\_nomad\_profile\_role](#output\_update\_nomad\_profile\_role) | n/a |
<!-- END_TF_DOCS -->
