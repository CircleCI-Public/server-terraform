{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor2",
            "Effect": "Allow",
            "Principal": {
                "Federated": "${OIDC_PRINCIPAL_ID}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                "${OIDC_EKS_VARIABLE}": "${K8S_SERVICE_ACCOUNT}"
                }
            }
        }

    ]
}