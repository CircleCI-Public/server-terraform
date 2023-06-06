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

  server_endpoint = "<< hostname of server installation >>"

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
  # for more info, visit - https://docs.aws.amazon.com/eks/latest/userguide/create-service-account-iam-policy-and-role.html
  enable_irsa = {}

  ssh_key = "<< public key to be placed on each nomad client >>"
  basename = "<< name prefix for nomad clients >>"
}

output "nomad" {
  value     = module.nomad_clients
  sensitive = true
}
```

There are more examples in the [examples](./examples/) directory.
- [Basic example](./examples/basic/main.tf)
- [IRSA example](./examples/irsa/main.tf)


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| basename | Name used as prefix for AWS resources | `string` | `""` | no |
| blocked\_cidrs | List of CIDR blocks to block access to from within jobs, e.g. your K8s nodes.<br>You won't want to block access to external VMs here.<br>It's okay when your dns\_server is within a blocked CIDR block, you can use var.dns\_server to create an exemption. | `list(string)` | n/a | yes |
| docker_network_cidr | CIDR block to use in Docker Network, Should not be same as subnetworks CIDR | `string` | `10.10.0.0/16` | no |
| dns\_server | If the IP address of your VPC DNS server is within one of the blocked CIDR blocks you can create an exemption by entering the IP address for it here | `string` | n/a | yes |
| enable\_mtls | MTLS support for Nomad traffic. Modifying this can be dangerous and is not recommended. | `bool` | `true` | no |
| instance\_type | AWS Node type for instance. Must be amd64 linux type.  The instance type must be large enough to fit the [resource classes](https://circleci.com/docs/2.0/executor-types/#available-docker-resource-classes) required.  Choosing smaller instance types is an opportunity for cost savings. | `string` | `"t3a.2xlarge"` | no |
| instance\_tags | Tags to apply to all Nomad client EC2 instances | `map(string)` | `{ "vendor" = "circleci" }` | no |
| max_nodes | Maximum number of nomad client to create when scaling. Should always be greater than or equal to the node count | `number` | 5 | no |
| nodes | Number of nomad client to create | `number` | n/a | yes |
| nomad_auto_scaler | If true, terraform will generate an IAM user to be used by nomad-autoscaler in CircleCI Server. The keys will be available in terraform's output | `bool` | false | no |
| role_name | Name of the role to add to the instance profile | `string` | `null` | no |
| volume\_type | The EBS volume type of the nomad nodes. If gp3 is not available in your desired region, switch to gp2 | `string` | `gp3` | no |
| security\_group\_id | ID for the security group for Nomad clients.<br>See security documentation for recommendations. | `list(string)` | `[]` | no |
| server\_endpoint | Hostname of the server installation | `string` | n/a | yes |
| ssh\_key | SSH Public key to access nomad nodes | `string` | `null` | no |
| subnet | Subnet ID | `string` | `""` | yes* |
| subnets | Subnet IDs | `list(string)` | `[""]` | yes* |
| vpc\_id | VPC ID of VPC used for Nomad resources | `string` | n/a | yes |
| enable_irsa | Enable IAM Roles for K8s service account | `map` | `{}` | no |
| machine_image_owners | List of AWS account IDs that own the images to be used for nomad virtual machines. | `list(string)` | `["099720109477", "513442679011"]` | no |
| machine_image_names | Strings to filter image names for nomad virtual machine images. | `list(string)` | `["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]` | no |

* Note: `subnet` or `subnets` is required, but not both. The use of `subnet` will supersede `subnets`.

## Outputs

| Name | Description |
|------|-------------|
| mtls\_enabled | set this value for the `nomad.server.rpc.mTLS.enabled` key in the [CircleCI Server's Helm values.yaml](https://circleci.com/docs/server/installation/installation-reference/#all-values-yaml-options) |
| nomad\_server\_cert | n/a |
| nomad\_server\_key | n/a |
| nomad\_tls\_ca | n/a |
| nomad\_server\_cert\_base64 | set this value for the `nomad.server.rpc.mTLS.certificate` key in the [CircleCI Server's Helm values.yaml](https://circleci.com/docs/server/installation/installation-reference/#all-values-yaml-options) |
| nomad\_server\_key\_base64 | set this value for the `nomad.server.rpc.mTLS.privateKey` key in the [CircleCI Server's Helm values.yaml](https://circleci.com/docs/server/installation/installation-reference/#all-values-yaml-options) |
| nomad\_tls\_ca\_base64 | set this value for the `nomad.server.rpc.mTLS.CACertificate` key in the [CircleCI Server's Helm values.yaml](https://circleci.com/docs/server/installation/installation-reference/#all-values-yaml-options) |
