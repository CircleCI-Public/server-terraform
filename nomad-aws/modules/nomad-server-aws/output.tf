output "role" {
  value = aws_iam_role.nomad_role.arn
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.autoscale.name
}

output "autoscaling_group_arn" {
  value = aws_autoscaling_group.autoscale.arn
}

output "autoscaling_group" {
  value = aws_autoscaling_group.autoscale
}

output "launch_template" {
  value = aws_launch_template.nomad-servers
}

output "target_group_4646" {
  value = aws_lb_target_group.target_group_4646
}

output "target_group_4647" {
  value = aws_lb_target_group.target_group_4647
}

output "target_group_4648" {
  value = aws_lb_target_group.target_group_4648
}