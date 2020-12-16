# Managing Access to your Kubernetes cluster
The following document assumes you have used the terraform scripts found in this repository to create a Kubernetes cluster for your CircleCI server installation. Below we go through our recommended approach to providing and managing user access.


## Overview

We recommend making only the bastion host accessible from the public internet. Thus, you can remove most risk of unauthorized access by simply stopping your bastion host while not in use. This will also give you two layers of access control:
* Who can connect to the bastion host
* What can a user do on the bastion host

## Managing bastion host SSH access

The bastion host has OS Login enabled which allows you to manage SSH access to the bastion using the IAM controls in GCP. Users with `roles/owner`, `roles/editor` or `roles/compute.instanceAdmin` permissions will automatically have administrator permissions, i.e. they may perform `sudo` commands on the bastion.  You can grant other users within the project access with the `roles/compute.osLogin` permission or sudo access with the `roles/compute.osAdminLogin` permission. Users should also have the `roles/iam.serviceAccountUser` role on the service account as this is the account the bastion host itself uses to authenticate against other services, e.g. the Kubernetes cluster. You can attach conditions to the role to ensure that users can impersonate the Service Account only on the bastion host.

This approach has the advantages that you don't need to manage SSH keys manually and that deactivating an IAM user will also prevent them from connecting to the bastion host. For this to work, a user needs to use Google's `glcoud` tool. Assuming a user has initialized gcloud (`gcloud init`), they can simply connect to the bastion using

`gcloud compute ssh <bastion-host-name> --project <project-name> --region <region-name>`

The `--project` and `--region` flags can be omitted if `gcloud` there were default values configured during initialization that can be used.

## Adding Users with Limited Resource Access
You may not wish for each user to have access to all cluster resources. To finely tune user access we make use of kubernetes' role based access control ([RBAC]).
In the following example we will create a role that will have limited access to a `develop` namespace and then map it to an IAM user. You will need to be a cluster administrator as detailed above to proceed with the following steps.

On the bastion host, make sure that your `kubectl` config is up-to-date and that you have all the necessary permissions.

1. First, we'll create a `role` that may only read pod data in the `develop` namespace.
- create a file called `read-role.yaml` and add the following:
```
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: pod-reader
  namespace: develop
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods"]
  verbs: ["list","get","watch"]
- apiGroups: ["extensions","apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
```

- and then apply the role to your cluster:
`kubectl apply -f read-role.yaml`

3. Now we will create a `role-binding` on the email address of our user's Google Cloud account and the pod-reader role in the cluster to define their access level.
- Create a file called `read-role-binding.yaml` and add the following: 
```
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: pod-reader-binding
  namespace: develop
subjects:
- kind: User
  name: <user-email>
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

- and then apply the role-binding to your cluster:
`kubectl apply -f read-role-binding.yaml`


Now your user will be able to access the cluster from the bastion but will only be able to view pod resources in the `develop` namespace.

For more details on managing permissions, you may read Google's [RBAC] documentation.


## Other Role Binding Subjects
RoleBindings are not limited to Google Cloud IAM users. The following other subjects are supported:
```
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: pod-reader-binding
  namespace: develop
subjects:
# Google Cloud user account
- kind: User
  name: janedoe@example.com
# Kubernetes service account
- kind: ServiceAccount
  name: johndoe
# IAM service account
- kind: User
  name: test-account@test-project-123456.google.com.iam.gserviceaccount.com
# Google Group
- kind: Group
  name: accounting-group@example.com
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

However, to use Google Groups, the group referenced here needs to be itself a member of the Google Group `gke-security-groups@<yourdomain>`, which you will probably need to create.


Sources and further reading:
[Configuring role-based access control (official GKE guide)](https://cloud.google.com/kubernetes-engine/docs/how-to/role-based-access-control)
[Intro to RBAC](https://www.eksworkshop.com/beginner/090_rbac/)
[Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

<!-- Links -->
[RBAC]: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
