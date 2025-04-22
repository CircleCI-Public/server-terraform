output "lb_arn" {
  value = aws_lb.internal_nlb.name
}

output "role" {
  value = aws_iam_role.nomad_role.arn
}

output "nomad_sg_id" {
  value = aws_security_group.nomad_server_sg.id
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.autoscale.name
}

output "autoscaling_group_arn" {
  value = aws_autoscaling_group.autoscale.arn
}