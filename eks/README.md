# CircleCI Server on EKS

## Assumptions and Requirements

It is assumed that an AWS account exists and that the deployer has
permissions to create, modify, and delete resources and IAM accounts. 

To deploy the infrastructure and application you will need to have the
following CLIs installed:


* [terraform] (tested with 0.13.5)
* [kubectl] (tested with 1.14.6)
* [kustomize] (tested with 3.6.1)
* [helm] (tested with 3.0.1)
* [awscli] (tested with 1.16.261)
* [kots]
* [server-keysets]
* Optional: [GPG](https://gpgtools.org/)


Additionally you will require the following permissions and access in order to
configure the CircleCI Server application:

* ID and secret for a Github OAuth application.
* An AWS [keypair][aws-keypair-docs]
* optional - certbot with Route53 `pip install certbot_dns_route53`

## Setup

1. Install any missing CLI tools listed above. Ensure access to listed
   services.
2. Clone `server-terraform` repository to your machine. `git clone
   git@github.com:circleci/server-terraform.git`
3. Assume going forward that all paths specified are relative to the root of
   the `server-terraform` repo.

### Optional
The following steps are optional if the IAM secret key needs to be encrypted in the terraform state file
1. Generate a PGP key: `gpg --full-generate-key`
2. Get a copy of the base64 encoded public key gpg --export <keyname> | base64 | pbcopy
3. Use the base64 encoded public key to populate the `pgp_key' terraform variable

## Deploy EKS Infrastructure with Terraform

1. Choose a basename for your EKS installation and set a BASENAME environment
   variable. Your basename must not exceed 20 characters in length!
2. Run `aws configure` to authenticate against AWS.  Alternativly you may set
   AWS_ACCESS_KEY, AWS_DEFAULT_REGION and AWS_SECRET_KEY environment variables.
3. Create a S3 bucket for terraform state: `aws s3 mb
   s3://${BASENAME}-terraform-state`
4. If you will be using a bastion, you will also need an SSH key. 
    * Generate an SSH key using a tool like ssh-keygen.  ex: `ssh-keygen -f
      ./circleci-bastion -t rsa -b 4096`.  This key will be used in the
`bastion_key` terraform variable. 
5. Navigate to `./eks`
6. Modify the `terraform.tfvars.template` file and save as `terraform.tfvars`
7. Run command: `terraform init`. This will initialize terraform, downloading
   any dependency providers, and creating a state object in a predefined s3
bucket.
8. Run command: `terraform plan`. This will compare the remote state to the
   definitions in the local terraform and create a plan for additions, changes
and removals.
9. Once the plan has been verified, run command: `terraform apply`. When
    prompted, confirm the deployment. Deployment time can vary but has
typically taken approximately ten minutes.  The output will include some data
values.  Take note of `cluster_name`, `subnet`, `vm_service_security_group`, 
`access-key-id` and one of  `secret-access-key` or `secret-access-key-encrypted`.
We'll need those values later.
10. Once deployment is complete, add the new EKS cluster to your local
    Kubernetes configuration via aws-cli by running the following command: `aws
eks update-kubeconfig --name $BASENAME-cci-cluster` Should you use a
bastion host, you can skip this step.
11. Verify that the credentials were added by running the following command:
    `kubectl config get-contexts` This should return a list of contexts with an
asterix beside the active context.  In case you are using a bastion host, you
need to connect to the bastion host first. Terraform will have provided you
with the IP after `terraform apply`: `ssh ubuntu@<bastion IP>`. After
connecting to the bastion host you can run the kubectl command above.

## Generate Certificate

If you already have a Certificate please skip to the next step.

A TLS certificate is required for proper operation of CircleCI Server.  A
free option is to use LetsEncrypt via certbot.

```shell
export domain=example-dev.eks.sphereci.com

certbot certonly \
    --config-dir=eks-config \
    --work-dir=eks-work \
    --logs-dir=eks-logs \
    --dns-route53 -d $domain
```

This will create a certificate along with chain of intermediate
certificates in `eks-config/live/$domain/fullchain.pem` and private
key in `eks-config/live/privkey.pem`. These files can be used in
Kots config to secure your installations with TLS.

You need a public DNS record in Route53 for your secondary domain if your
hostname already contains a subdomain: If you want to register your
installation as `circleci.dev.example.com`, you will need to have a public
record for `dev.example.com` for this step to succeed.


### Known Problems: ###

- `Terraform destroy` fails on subnet and internet gateway sometimes.  The VPC
  also will have still be there but the terraform output does not show that.
These must be deleted manually.
  - Start by deleting all the Load Balancers.  Identify them based on tag.
  - Then Delete the VPC
  - then run `terraform destroy` again and it will probably show 0 to destroy.
    Problem solved!
- Network Interfaces don't get any tags.  This is probably something in the
  module implementation
- Something tags subnets with
  `"kubernetes.io/cluster/christopher-eks-cci-cluster" = "shared" -> null`
after terraform has run so that subsequent runs always show removal of that as
a change

<!-- Links -->
[terraform]: https://releases.hashicorp.com/terraform/0.13.5/
[kubectl]: https://storage.googleapis.com/kubernetes-release/release/v1.14.6/bin/darwin/amd64/kubectl
[kustomize]: https://github.com/kubernetes-sigs/kustomize/releases/tag/kustomize%2Fv3.6.1
[helm]: https://get.helm.sh/helm-v3.0.1-linux-amd64.tar.gz
[awscli]: https://aws.amazon.com/cli/
[kots]: https://kots.io/kots-cli/getting-started/
[server-keysets]: https://hub.docker.com/repository/docker/circleci/server-keysets
[aws-keypair-docs]: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-ec2-keypairs.html
