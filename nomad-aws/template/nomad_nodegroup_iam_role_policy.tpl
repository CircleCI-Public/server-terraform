{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": [
				"autoscaling:CreateOrUpdateTags",
				"autoscaling:DescribeAutoScalingGroups",
				"autoscaling:DescribeScalingActivities",
				"autoscaling:TerminateInstanceInAutoScalingGroup",
				"autoscaling:UpdateAutoScalingGroup"
			],
			"Resource": [
				"*"
			]
		}
	]
}
