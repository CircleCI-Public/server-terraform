# CircleCI Server on EKS

## Assumptions and Requirements

It is assumed that an AWS account exists and that the deployer has
permissions to create, modify, and delete resources and IAM accounts. 

To deploy the infrastructure and application you will need to have the
following CLIs installed:


* [terraform] (tested with 0.14.2)
* [kubectl] (tested with 1.20.0
* [awscli] (tested with 1.16.261)
* [server-keysets]


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

## Deploy EKS Infrastructure with Terraform

1. Choose a basename for your EKS installation and set a BASENAME environment
   variable. Your basename must not exceed 20 characters in length!
2. Run `aws configure` to authenticate against AWS.  Alternativly you may set
   AWS_ACCESS_KEY, AWS_DEFAULT_REGION and AWS_SECRET_KEY environment variables.
3. Create a S3 bucket for terraform state: `aws s3 mb s3://${BASENAME}-terraform-state`
4. If you will be using a bastion, you will also need an SSH key. 
    * Generate an SSH key using a tool like ssh-keygen.  
     ex: `ssh-keygen -f ./circleci-bastion -t rsa -b 4096`
     This key will be used in the `bastion_key` terraform variable. 
5. Navigate to `./eks`
6. Modify the `terraform.tfvars.template` file and save as `terraform.tfvars`
7. Modify the `remote_state.tf.template` file using the same values from
   `terraform.tfvars` and save as `remote_state.tf`
8. Run command: `terraform init`. This will initialize terraform, downloading
   any dependency providers, and creating a state object in a predefined s3
bucket.
9. Run command: `terraform plan`. This will compare the remote state to the
   definitions in the local terraform and create a plan for additions, changes
and removals.
10. Once the plan has been verified, run command: `terraform apply`. When
    prompted, confirm the deployment. Deployment time can vary but has
typically taken approximately ten minutes.  The output will include some data
values.  Take note of `cluster_name`, `subnet`, `vm_service_security_group`, 
`access-key-id` and one of  `secret-access-key` or `secret-access-key-encrypted`.
We'll need those values later.
11. Once deployment is complete, add the new EKS cluster to your local
    Kubernetes configuration via aws-cli by running the following command: `aws
eks update-kubeconfig --name $BASENAME-cci-cluster` Should you use a
bastion host, you can skip this step.
12. Verify that the credentials were added by running the following command:
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
key in `eks-config/live/$domain/privkey.pem`. These files can be used in
your Server 3.0 config to secure your installations with TLS.

You need a public DNS record in Route53 for your secondary domain if your
hostname already contains a subdomain: If you want to register your
installation as `circleci.dev.example.com`, you will need to have a public
record for `dev.example.com` for this step to succeed.


### Known Problems: ###

- Running `terraform destroy` fails on subnet and internet gateway sometimes. The VPC
  also will have still be there but the terraform output does not show that. These must be deleted manually.
  - Start by deleting all the Load Balancers.  Identify them based on tag.
  - Then Delete the VPC
  - then run `terraform destroy` again and it will probably show 0 to destroy. Problem solved!
- Network Interfaces don't get any tags.  This is probably something in the
  module implementation
- On running `terraform apply` subnets will be tagged with:
  `"kubernetes.io/cluster/<basename>-cci-cluster" = "shared" -> null`
  Subsequent `terraform apply` runs always show removal of that as a change

<!-- Links -->
[terraform]: https://releases.hashicorp.com/terraform/0.14.2/
[kubectl]: https://kubernetes.io/docs/tasks/tools/install-kubectl/
[awscli]: https://aws.amazon.com/cli/
[server-keysets]: https://github.com/CircleCI-Public/server-keysets-cli#using-the-docker-container
[aws-keypair-docs]: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-ec2-keypairs.html
