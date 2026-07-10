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
%{ if SUB_IS_WILDCARD }
                "StringEquals": {
                "${OIDC_EKS_VARIABLE}:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                "${OIDC_EKS_VARIABLE}:sub": "${K8S_SERVICE_ACCOUNT}"
                }
%{ else }
                "StringEquals": {
                "${OIDC_EKS_VARIABLE}:aud": "sts.amazonaws.com",
                "${OIDC_EKS_VARIABLE}:sub": "${K8S_SERVICE_ACCOUNT}"
                }
%{ endif }
            }
        }

    ]
}
