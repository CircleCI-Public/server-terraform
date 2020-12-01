# Managing Access to your Kubernetes cluster
The following document assumes you have used the terraform scripts found in this repository to create a Kubernetes cluster for your CircleCI server installation. Below we go through our recommended approach to providing and managing user access.


## Adding Cluster Administrators
Cluster admins are first registered via appending their IPs and IAM user details to the appropriate lists in your `terraform.tfvars` file.

example:
```
allowed_cidr_blocks = ["user_ip/32","user1_ip/32"]
k8s_administrators = [
  {
      groups   = ["system:masters"]
      userarn  = "<user ARN>"
      username = "<username>"
  },
  {
      groups   = ["system:masters"]
      userarn  = "<user1 ARN>"
      username = "<user1name>"
  }
}
```

Upon `terrafrom apply`, these fields will whitelist your IPs, and add the list of users will be added to the system:masters group for full access to all resources in the cluster.

### Updating the Cluster admin list
If you wish to add/remove admin users from your existing cluster, you only need to update the values in your `terraform.tfvars` and run `terrafrom apply`.

## Adding Users with Limited Resource Access
You may not wish for each user to have complete access of to all cluster resources. To more finely tune user access we will make use kubernetes role based access control ([RBAC]).
In the following example we will create a role which will have limited access to a `develop` namespace and then map it to an IAM user. You will need to be a cluster administrator as detailed above to proceed with the following steps.

We'll first we'll need to add the user's ARN to the aws-auth configmap in the kube-system namespace.

1. First we edit the `aws-auth` configmap:
- Create a local copy of the aws-auth configmap: `kubectl get configmap -n kube-system aws-auth -o yaml > aws-auth.yaml`

- Then add the user details under `mapUsers` in the configmap's data:
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapUsers: |
    - userarn: arn:aws:iam::<account>:user/<dev-user>
      username: <dev-user>
```

- Apply your changes:
`kubectl apply -f aws-auth.yaml`


2. Now we'll create a `role` that may only read pod data in the `develop` namespace.
- add the following to a file called `read-role.yaml`:
```
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: develop
  name: pod-reader
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


3. Now we'll create a `role-binding` on our user's ARN and the pod-reader role in the cluster to define their access level.
- add the following to a file call `read-role-binding.yaml`
```
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: read-pods
  namespace: rbac-test
subjects:
- kind: User
  name: rbac-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

- and then apply the role-binding to your cluster:
`kubectl apply -f read-role-binding.yaml`

4. Finally to grant access to the cluster, you will need to whitelist the user's IP address.
- As with admin users, we will need to add the user's IP to your terrafrom.tfvars and `terraform apply`

Now your user will be able to access the cluster but will only be able to view pod resources in the develop namespace.

For more details on managing permissions, you may read the google's [RBAC] documentation.


<!-- Links -->
[RBAC]: https://kubernetes.io/docs/reference/access-authn-authz/rbac/