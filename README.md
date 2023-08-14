[![CircleCI](https://circleci.com/gh/CircleCI-Public/server-terraform.svg?style=shield)](https://circleci.com/gh/CircleCI-Public/server-terraform)

# Server Terraform

This repository contains a collection of [Terraform](https://www.terraform.io)
modules that are helpful in hosting CircleCI server >= 3.x.

## Contents

- [AWS Nomad Clients](./nomad-aws/README.md)
- [GCP Nomad Clients](./nomad-gcp/README.md)

## Usage

We strongly suggest consuming these modules using Terraform [generic git
repository] support and pinning a fixed reference. For example, you might
consume the AWS Nomad client module as follows:

```terraform
module "my-aws-nomad-clients" {
  # Pin release to 4.1.0 (for example) and use /nomad-aws subdirectory
  source = "git::https://github.com/CircleCI-Public/server-terraform.git//nomad-aws?ref=4.1.0"

  # Other variables here...
}
```

> Note the use of `ref=4.1.0` to select a specific git tag and
> `//nomad-aws` to select the `nomad-aws` module.

[generic git repository]: https://www.terraform.io/docs/language/modules/sources.html#generic-git-repository

## Compatibility

The modules in this repository are meant to be used with [terraform
v0.15.4](https://releases.hashicorp.com/terraform/0.15.4/) and above.

### M1 Macbooks

If using an M1 Macbook to run terraform init, plan, or apply commands, it's possible you may run into a versioning error with the hashicorp/tls provider. For this, we recommend the [m1-terraform-provider-helper](https://github.com/kreuzwerker/m1-terraform-provider-helper) CLI tool.

First, navigate to the directory where you attempted the `terraform init/plan/apply` command and faced the error. Then run the following to install the provider compatible with the M1 Mac, double checking that the version matches that listed [here](shared/modules/tls/main.tf).

```bash
m1-terraform-provider-helper install hashicorp/tls -v v3.2.0
```

---

## How to contribute

We love contributions! Here is how to get started:

### Creating a PR

- Start by branching off main. Branches should be named with the issue number
  they resolve or a description of the work being done.
- Once your work is complete, you may create a PR for your branch
- Each commit is tested for formatting and syntax errors
- We test PRs in our own test environments
- PRs are reviewed and approved by members of CircleCI's Server team

### Reporting Issues

- Feature requests or problems found may be reported by creating an issue
  within this repository
- CircleCI's Server team will review and respond to issues.
