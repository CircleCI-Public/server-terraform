resource "aws_route53_zone" "internal_dns" {
  name          = "${var.basename}.circleci.internal"
  force_destroy = true
  vpc {
    vpc_id = module.vpc.vpc_id
  }
}
