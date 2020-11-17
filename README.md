# server-terraform [Beta]

## Introduction
This repository contains the terraform scripts for deploying the resources necessary for hosting your own CircleCi Server instance on Kubernetes. For images, helmcharts, ete, related to the services used in a CircleCi Server Instance.
Currently this project is still in beta and supports 2 cloud providers, AWS and GCP with the intent to expand support in future releases.

## Compatibility
The modules in this repository are meant to be used with [terraform v0.13.5](https://github.com/hashicorp/terraform/releases/tag/v0.13.5)

## How to get started
Documentation on setting up an environment for launching in either cloud providers we support are found here:
1. [GKE](gke/README.md)
2. [EKS](eks/README.md)


## How to contribute
You may contribute to server-terraform by:

### Creating a PR
Creating a Branch
- Start by branching off main. Branches should be named with the issue number they resolve or a description of the work being done.
- Once your work is complete, you may create a PR for your branch
- each commit is tested for formatting and syntax errors in terraform and shell scripts
- we then test PRs in our own test enfironments
- PRs are reviewed and approved by members of CircleCi's Server team

### Reporting Issues
- Feature requests or problems found may be reported by createing an issue within this repository
- CircleCi's server team will review and respond to issues.
- Guides on creating issues will be added soon