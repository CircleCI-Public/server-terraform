# Managing Access to your Kubernetes cluster The following document assumes you
have used the terraform scripts found in this repository to create a Kubernetes
cluster for your CircleCI server installation. Furthermore, it is assumed that
you have used the default values which will set up a kubernetes cluster with a
bastion host and no public endpoint. Below we go through our recommended
approach to providing and managing user access.

## Access to the bastion

Access to the bastion is granted via EC2 Instance Connect so that you do not
have to manage and share SSH keys yourself. To allow a user access to the
bastion, they must have the `ec2-instance-connect:SendSSHPublicKey` permission
for the bastion. For your convenience, an IAM policy is created for you that
you can assign to users or roles you want to have access to the bastion:
`<basename>-cci-cluster-bastion_access`. Simply attach it to any user or group
you want to grant access to your bastion and make sure that their IPs are added
to the `allowed_cidr_blocks`. Keep in mind that users who already have
extensive permissions within your AWS account might be able to access the
bastion without having been granted permission explicitly.

For a user to connect to the bastion, they can either use the EC2 Instance
Connect option from the AWS Console in their browser or install the EC2
Instance Connect CLI with `pip`:

`pip install ec2instanceconnectcli`

To connect to the bastion host, use the following command:

`mssh ubuntu@<bastion host instance ID>`

Keep in mind that the ubuntu user has `sudo` access. If you want to create a
less-privileged user, you would have to create it on the bastion host and add a
separate IAM role for this OS user, specifying the bastion host username as
condition on the IAM policy granting the user the
`ec2-instance-connect:SendSSHPublicKey` permission for the bastion:

```
…
"Condition": {
    "StringEquals": {
        "ec2:osuser": "<bastion host username>"
    }
}
…
```

You can also still use the `ssh` command to connect to the bastion host if you
push your public ssh key to the instance first:
```
aws ec2-instance-connect send-ssh-public-key \
    --instance-id <bastion host instance ID> \
    --availability-zone <bastion host region> \
    --instance-os-user ubuntu \
    --ssh-public-key file://my_rsa_key.pub
```
After runnning this command you can connect to the bastion host with `ssh`
using your private key and using the ubuntu user for 60 seconds. After 60
seconds, the key will be removed from the bastion host automatically.

As `mssh` doesn't support the `-L` flag for port-forwarding, you probably want
to alias the command above for pushing your ssh key and use `ssh` for
port-forwarding. You will use port-forwarding via the bastion for accessing
the kots admin console like so:
```
ssh -i <path to your rsa key> ubuntu@<bastion host IP> -- -f kubectl kots admin-console -n <your cluster namespace>; \
ssh -i <path to your rsa key> ubuntu@<bastion host IP> -- -NnL 8800:localhost:8800; \
ssh -i <path to your rsa key> ubuntu@<bastion host IP> -- killall kubectl-kots
```
The first command connects the bastion to kots admin console. The second
command forwards the port to the admin console to your local machine. As soon
as you CTRL+C out of this command, the third command will close the connection
between the bastion and kots admin console.

## Adding Cluster Administrators when using a public endpoint Should you use a
public endpoint, you can register cluster admins via appending their IPs and
IAM user details to the appropriate lists in your `terraform.tfvars` file.

Example:
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

If you are using a bastion host, the bastion host's instance role is registered
as a cluster admin automatically and the list in the `terraform.tfvars` file
has no effect.

### Updating the Cluster admin list If you wish to add/remove admin users from
your existing cluster, you only need to update the values in your
`terraform.tfvars` and run `terrafrom apply`.

## Adding Users with Limited Resource Access You may not wish for each user to
have complete access of to all cluster resources. To more finely tune user
access we make use of kubernetes' role based access control ([RBAC]).  In the
following example we will create a role which will have limited access to a
`develop` namespace and then map it to an IAM user. You will need to be
connected to the bastion host or, should you use a public endpoint, be a
cluster administrator as detailed above to proceed with the following steps.

First we will need to add the user's ARN to the aws-auth configmap in the
kube-system namespace.

1. First we edit the `aws-auth` configmap:
- Create a local copy of the aws-auth configmap:
  `kubectl get configmap -n kube-system aws-auth -o yaml > aws-auth.yaml`

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


3. Now we will create a `role-binding` on our user's ARN and the pod-reader
   role in the cluster to define their access level.
- add the following to a file called `read-role-binding.yaml`
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

4. Finally, to grant access to the cluster, you will need to whitelist the
user's IP address.
- As with admin users, we will need to add the user's IP to your
  terrafrom.tfvars and `terraform apply`

Now your user will be able to access the cluster but will only be able to view
pod resources in the develop namespace.

For more details on managing permissions, you may read Google's [RBAC]
documentation.


## Providing Access with IAM Groups You may not wish to repeat the process
above for each user you wish to add. Many users will require the same access
levels. We can limit the repitition by assigning users to IAM groups.  Similary
to users, groups may also be mapped to roles to provide access management.

1. First create an IAM role:
```
ACCOUNT_ID=<<your aws account id>>
POLICY=$(echo -n '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::'; echo -n "$ACCOUNT_ID"; echo -n ':root"},"Action":"sts:AssumeRole","Condition":{}}]}')

echo ACCOUNT_ID=$ACCOUNT_ID
echo POLICY=$POLICY

aws iam create-role \
  --role-name k8sDev \
  --description "Kubernetes developer role (for AWS IAM Authenticator for Kubernetes)." \
  --assume-role-policy-document "$POLICY" \
  --output text \
  --query 'Role.Arn'
```

2. Create an IAM group:
```
aws iam create-group --group-name k8sDev

DEV_GROUP_POLICY=$(echo -n '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAssumeOrganizationAccountRole",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::'; echo -n "$ACCOUNT_ID"; echo -n ':role/k8sDev"
    }
  ]
}')
echo DEV_GROUP_POLICY=$DEV_GROUP_POLICY

aws iam put-group-policy \
--group-name k8sDev \
--policy-name k8sDev-policy \
--policy-document "$DEV_GROUP_POLICY"
```

3. Next we create the role and role-binding:
- create a file called dev-role-binding.yaml with the following. We will be
  applying these resources to the `develop` namespace as before.
```
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: dev-role
  namespace: develop
rules:
  - apiGroups:
      - ""
      - "apps"
      - "batch"
      - "extensions"
    resources:
      - "configmaps"
      - "cronjobs"
      - "deployments"
      - "events"
      - "ingresses"
      - "jobs"
      - "pods"
      - "pods/attach"
      - "pods/exec"
      - "pods/log"
      - "pods/portforward"
      - "secrets"
      - "services"
    verbs:
      - "create"
      - "delete"
      - "describe"
      - "get"
      - "list"
      - "patch"
      - "update"
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: dev-role-binding
  namespace: develop
subjects:
- kind: User
  name: dev-user
roleRef:
  kind: Role
  name: dev-role
  apiGroup: rbac.authorization.k8s.io
```

4. Then create the mapping of the IAM role to our k8s dev user
- Create a local copy of the aws-auth configmap:
  `kubectl get configmap -n kube-system aws-auth -o yaml > aws-auth.yaml`

- Then add the user details under `mapUsers` in the configmap's data:
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::<account>:role/k8sDev
      username: dev-user
  mapUsers: |
    []
```

- Apply your changes:
`kubectl apply -f aws-auth.yaml`

5. Now when you need to give a user dev access you can simply:
- add them to the dev group you created
  `aws iam add-user-to-group --group-name k8sDev --user-name <username>`

- and update the terraform.tfvars with their IP, then run `terraform apply`

## Acessing the Nomad clients

There are two ways how you can access the nomad clients. By default, you can
connect to the nomad clients using the bastion host using mssh. You connect to
the bastion host first and on the bastion host, you run the same command again
`mssh ubuntu@<instance id of the Nomad client>`.

Alternatively, you can provide your own SSH key for the Nomad clients, using
the `nomad-ssh-key` terraform variable. If you don't set the
`nomad_public_ssh_port` variable to `true`, you will need to copy the private
key to the bastion host yourself.


Sources and further reading:
[AWS Managing users or IAM roles for your cluster](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html)
[Intro to RBAC](https://www.eksworkshop.com/beginner/090_rbac/)
[Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

<!-- Links -->
[RBAC]: https://kubernetes.io/docs/reference/access-authn-authz/rbac/