{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:DescribeScalingActivities",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:CreateOrUpdateTags",
        "autoscaling:TerminateInstanceInAutoScalingGroup"
      ],
      "Resource": "${ASG_ARN}"
    }
  ]
}