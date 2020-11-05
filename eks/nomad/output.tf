output "nomad_sg_id" {
  value = aws_security_group.nomad_sg[0].id
}