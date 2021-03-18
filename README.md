# Server Terraform [Beta]

This repository contains a collection of [Terraform](https://www.terraform.io)
modules that are helpful in hosting CircleCI server 3.0.

## Contents

- [AWS Nomad Clients](./nomad-aws/README.md)
- [GCP Nomad Clients](./nomad-gcp/README.md)

## Usage

We strongly suggest consuming these modules using Terraform [generic git
repository] support and pinning a fixed reference. For example, you might
consume the AWS Nomad client module as follows:

```terraform
module "my-aws-nomad-clients" {
  # Pin release to 3.0.0-RC7 (for example) and use /nomad-aws subdirectory
  source = "git::https://github.com/CircleCI-Public/server-terraform.git//nomad-aws?ref=3.0.0-RC7"
  
  # Other variables here... 
}
```

> Note the use of `ref=3.0.0-RC7` to select a specific git tag and
> `//nomad-aws` to select the `nomad-aws` module.

[generic git repository]: https://www.terraform.io/docs/language/modules/sources.html#generic-git-repository

## Compatibility

The modules in this repository are meant to be used with [terraform
v0.14.2](https://releases.hashicorp.com/terraform/0.14.2/) and above.

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
