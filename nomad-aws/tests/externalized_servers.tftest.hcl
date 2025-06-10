mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id = "ami-12345678"
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id         = "vpc-12345678"
      cidr_block = "192.168.0.0/16"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = <<-EOF
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Action": "ec2:DescribeInstances",
            "Resource": "*"
          }
        ]
      }
      EOF
    }
  }

  mock_resource "aws_launch_template" {
    defaults = {
      id = "lt-12345678"
    }
  }

  mock_resource "aws_autoscaling_group" {
    defaults = {
      id = "asg-12345678"
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      id  = "nlb-12345678"
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/nomad-nlb/1234567890123456"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      id  = "tg-12345678"
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/nomad-tg/1234567890123456"
    }
  }

  mock_resource "aws_security_group" {
    defaults = {
      id = "sg-12345678"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      id  = "nomad-server-role"
      arn = "arn:aws:iam::123456789012:role/nomad-server-role"
    }
  }

  mock_resource "aws_iam_instance_profile" {
    defaults = {
      id  = "nomad-server-profile"
      arn = "arn:aws:iam::123456789012:instance-profile/nomad-server-profile"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      id  = "policy-12345678"
      arn = "arn:aws:iam::123456789012:policy/nomad-describe-ec2-policy"
    }
  }
}

run "test_server_launch_template" {
  variables {
    basename              = "test"
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 2
    vpc_id                = "vpc-12345678"
    subnets               = ["subnet-12345678"]
    deploy_nomad_server_instances  = true
    server_machine_type   = "m5.xlarge"
    server_disk_size_gb   = 50
  }

  assert {
    condition     = module.server[0].launch_template.instance_type == "m5.xlarge"
    error_message = "Launch template should use specified instance type"
  }

  assert {
    condition     = module.server[0].launch_template.image_id == "ami-12345678"
    error_message = "Launch template should use mocked AMI"
  }

  assert {
    condition     = module.server[0].launch_template.block_device_mappings[0].ebs[0].volume_size == 50
    error_message = "Launch template should have correct disk size"
  }
}

run "test_server_autoscaling_group" {
  variables {
    basename                = "test"
    nomad_server_hostname   = "example.com"
    blocked_cidrs           = ["192.168.1.0/24"]
    dns_server              = "192.168.0.2"
    nodes                   = 2
    vpc_id                  = "vpc-12345678"
    subnets                 = ["subnet-12345678"]
    deploy_nomad_server_instances    = true
    desired_server_instances = 3
    max_server_instances     = 7
  }

  assert {
    condition     = module.server[0].autoscaling_group.desired_capacity == 3
    error_message = "ASG desired capacity should match variable"
  }

  assert {
    condition     = module.server[0].autoscaling_group.max_size == 7
    error_message = "ASG max size should match variable"
  }
}

run "test_load_balancer_configuration" {
  variables {
    basename              = "test"
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 2
    vpc_id                = "vpc-12345678"
    subnets               = ["subnet-12345678"]
    deploy_nomad_server_instances  = true
  }

  assert {
    condition     = module.server[0].load_balancer.internal == true
    error_message = "Load balancer should be internal"
  }

  assert {
    condition     = module.server[0].load_balancer.load_balancer_type == "network"
    error_message = "Load balancer should be network type"
  }

  assert {
    condition     = module.server[0].target_group_4646.port == 4646
    error_message = "Target group should be configured for port 4646"
  }

  assert {
    condition     = module.server[0].target_group_4647.port == 4647
    error_message = "Target group should be configured for port 4647"
  }

  assert {
    condition     = module.server[0].target_group_4648.port == 4648
    error_message = "Target group should be configured for port 4648"
  }
}
