# CircleCI Server on GKE

## Assumptions and Requirements

It is assumed that a Google Cloud project exists and that the deployer
has permissions to create, modify, and delete resources and Service Accounts.

To deploy the infrastructure and application you will need to have the
following CLIs installed:

* [terraform] (tested with 0.14.2)
* [kubectl] (tested with 1.14.6)
* [gcloud] (tested with 301.0.0)
* [server-keysets]
  (Actual installation is unnecessary; the Docker image will be pulled
  automatically when you attempt to use it.)
* optional - certbot with google-dns plugin (tested with 0.39.0)
  plugin install: `pip install certbot-dns-google`

Additionally you will require the following permissions and access in order to
configure the CircleCI Server application:

* You use google DNS to manage the CircleCI Server subdomain
* ID and secret for a Github OAuth application.
* A GCP Service Account with [keys][gcloud-service-account-keys]

### macOS dependency installation (Homebrew)

The tools can be installed on macOS using (mainly) Homebrew with:

```sh
# Install Terraform, Kustomize, Helm, and Certbot
brew install terraform kustomize helm certbot
# Install Docker (which installs kubctl) and GCloud SDK.
# Skip `docker` here if you already have it installed another way.
brew cask install docker google-cloud-sdk
# Install Kots.
curl https://kots.io/install | bash
```

## Setup

1. Install any missing CLI tools listed above. Ensure access to listed
   services.
2. Clone `server-terraform` repository to your machine.
	`git clone git@github.com:circleci/server-terraform.git`
3. Assume going forward that all paths specified are relative to the root of
   the `server-terraform` repo.

## Deploy GKE Infrastructure with Terraform

This assumes the default configuration with a private cluster behind a bastion host.

1. Configure Google Cloud credentials. You can do this in one of two ways:
    * Set up [user default application credentials]  via `gcloud auth
      application-default login`. You may use the `--project` flag to select a
GCP project.
    * Use service account credentials. First configure environment variables
      `export GOOGLE_APPLICATION_CREDENTIALS="<path to SAkey.json>"` and then
activate your service account via `gcloud auth activate-service-account
--key-file=$GOOGLE_APPLICATION_CREDENTIALS`
2. Choose a base name
    `export BASENAME=<name>`
    Suggested `<yourname>-dev`. This will be used to name Google Cloud resources,
    and should be no longer than 15 characters to fit their naming constraints.
3. Navigate to `./gke`
4. Create a bucket for terraform state `gsutil mb
   gs://${BASENAME}-terraform-state`
6. Modify the `remote-state.tf.template` and save as `remote-state.tf`
    * Under `backend "gcs"`, edit the `bucket` variable to point to your
      storage bucket you just created `<base-name>-terraform-state.
7. Modify the `terraform.tfvars.template` file and save as `terraform.tfvars`
8. Run command: `terraform init`. This will initialize terraform, downloading
   any dependency providers, and creating a state object in a predefined google
storage bucket. Should any errors occur at this stage ensure that gcloud has
been configured on your machine.
9. Run command: `terraform plan`. This will compare the remote state to the
   definitions in the local terraform and create a plan for additions, changes
and removals.
10. Once the plan has been verified, run command: `terraform apply` And when
    prompted, confirm the deployment. Deployment time can vary but has
typically taken approximately ten minutes.
11. Once deployment is complete, Terraform will display the name of the bastion host and the name and IP of the cluster. You can now connect to your bastion host:

`gcloud compute ssh <bastion-host-name> --project <project-name> --region <region-name>`

The `--project` and `--region` flags can be omitted if `gcloud` the default values configured during initialization can be used. If you have previously used service account credentials, switch back to use your user account credentials before connecting to the bastion: `gcloud auth login`.

You will need to connect to the bastion whenever you need to access the cluster or some of its components.

12. On the bastion, initialize gcloud: `gcloud init` – please make sure that you are using your own credentials and not the bastion host's Service Account. The Service Account doesn't have any relevant permissions and will prevent you from working effectively on the cluster.

13. Add the new GKE cluster to the Kubernetes configuration via gcloud by running the following command:
```
gcloud container clusters get-credentials [CLUSTER NAME]
```
14. Verify that the credentials were added by running the following command:
    `kubectl config get-contexts` This should return a list of contexts with an
asterisk beside the active context.

[user default application credentials]: https://cloud.google.com/sdk/gcloud/reference/auth/application-default

## Generate Certificate (optional)

If you already have a Certificate please skip to the next step.

A TLS certificate is required for proper operation of CircleCI Server.  A
free option is to use LetsEncrypt via certbot.

```shell
export domain=example-dev.gke.sphereci.com

certbot certonly \
    --dns-google \
    --dns-google-credentials ${GOOGLE_APPLICATION_CREDENTIALS} \
    --config-dir=gke-config \
    --work-dir=gke-work \
    --logs-dir=gke-logs \
    -d $domain
```

This will create a certificate along with chain of intermediate
certificates in `gke-config/live/$domain/fullchain.pem` and private
key in `gke-config/live/$domain/privkey.pem`. These files can be used in
Kots config to secure your installations with TLS.

### Resources

[Google Clouds Supported Resources Page]

#### Service Account for Nomad clients

By default we create a Service Account for the Nomad clients but we
do not add any privileges to them. In the event an operator wants to
assign privileges to the Nomad clients, they should do so through
`nomad_service_account`.

Please note that inherent risk of granting privileges to the Nomad clients
as arbitrary code runs in them. This is an advanced feature that should only
be used with the full understanding of the privileges being assigned.

#### GCloud tip for machines and clusters that don't have external networking interfaces

You can copy the `ssh` command to get into a machine from the console page that
lists all the instances in a project, however it is not possible to `ssh`
directly to a machine with no external NIC. After copying the command to get
into the jump box, you can append `-- -A` to the copied command and it will
forward your `ssh` credentials so that you can then get into the desired box
from there.

The leading `--` says "pass the following arguments down to the underlying
`ssh` command" when you run `gcloud compute ssh....`. The `-A` tells `ssh` to
forward creds to the next machine for you so that you don't have to copy a key
around.

<!-- Links -->
[terraform]: https://releases.hashicorp.com/terraform/0.14.2/
[kubectl]: https://kubernetes.io/docs/tasks/tools/install-kubectl/
[server-keysets]: https://github.com/CircleCI-Public/server-keysets-cli#using-the-docker-container
[gcloud]: https://cloud.google.com/sdk/install
[gcloud-service-account-keys]: https://cloud.google.com/docs/authentication/production#creating_a_service_account
[Google Clouds Supported Resources Page]: https://cloud.google.com/deployment-manager/docs/configuration/supported-resource-types
