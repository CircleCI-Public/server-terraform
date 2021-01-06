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
* An AWS role with administrator permissions
* optional - an AWS [keypair][aws-keypair-docs]
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
4. If you will be using a bastion (the default setting), you need to decide how you
   want to handle authentication with the bastion host. You can either manage SSH
   keys yourself or use [EC2 Instance Connect](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Connect-using-EC2-Instance-Connect.html) (recommended).
    * For EC2 Instance Connect:
        * You do not need to do anything special here
    * If you manage SSH keys yourself:
        * Generate an SSH key using a tool like ssh-keygen.
         ex: `ssh-keygen -f ./circleci-bastion -t rsa -b 4096`
         This key will be used in the `bastion_key` terraform variable.
5. Create a role that has sufficient permissions to create all the resources in
   this terraform. Ensure that you can assume the role with your local
   credentials and add EC2 to the trust policy of the role. The `arn` of this
   role will be used for the `additional_bastion_role_arn` terraform variable.
6. Navigate to `./eks`
7. Modify the `terraform.tfvars.template` file and save as `terraform.tfvars`
8. Modify the `remote_state.tf.template` file using the same values from
   `terraform.tfvars` and save as `remote_state.tf`
9. Run command: `terraform init`. This will initialize terraform, downloading
   any dependency providers, and creating a state object in a predefined s3
bucket.
10. Run command: `terraform plan`. This will compare the remote state to the
   definitions in the local terraform and create a plan for additions, changes
and removals.
11. Once the plan has been verified, run command: `terraform apply`. When
    prompted, confirm the deployment. Deployment time can vary but has
typically taken approximately ten minutes.  The output will include some data
values.  Take note of `cluster_name`, `subnet`, `vm_service_security_group`.
We'll need those values later.
12. Once deployment is complete,
    * if you have a bastion:
        * Connect to your bastion host with the command given in the terraform output
        * On the bastion, run some `kubectl` command to verify that you can access
          the cluster, e.g. `kubectl config get-contexts`.  This should return a
          list of contexts with an asterisk beside the active context. `kubectl` is
          aliased with `k` and `kubectl` autocompletion is enabled for your
          convenience.
        * You can now remove EC2 from the trust policy of the role you used for setting
          up the cluster. It was only needed to allow the bastion host to configure
          the EKS cluster for bastion host access. Keep the role around, though, in case
          you need to make changes to your setup at a later stage.
    * if you don't have a bastion:
        * add the new EKS cluster to your local Kubernetes configuration via aws-cli by
          running the following command:
          `aws eks update-kubeconfig --name $BASENAME-cci-cluster`
        * Verify that you can interact with the cluster, e.g. by running
          `kubectl config get-contexts`. This should return a list of contexts with an
          asterix beside the active context - which should point to your EKS cluster.

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
