# server-terraform [Beta]

## Introduction
This repository contains the terraform scripts for deploying the resources necessary for hosting your own CircleCI Server instance on Kubernetes.
Currently this project is still in beta and supports 2 cloud providers, AWS and GCP with the intent to expand support in future releases.

## Compatibility
The modules in this repository are meant to be used with [terraform v0.14.2](https://releases.hashicorp.com/terraform/0.14.2/)

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
- Each commit is tested for formatting and syntax errors
- We test PRs in our own test environments
- PRs are reviewed and approved by members of CircleCI's Server team

### Reporting Issues
- Feature requests or problems found may be reported by createing an issue within this repository
- CircleCI's Server team will review and respond to issues.
