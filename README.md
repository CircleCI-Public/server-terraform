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
