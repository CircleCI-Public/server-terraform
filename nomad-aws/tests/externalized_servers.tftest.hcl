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
    basename                      = "test"
    nomad_server_hostname         = "example.com"
    blocked_cidrs                 = ["192.168.1.0/24"]
    dns_server                    = "192.168.0.2"
    nodes                         = 2
    vpc_id                        = "vpc-12345678"
    subnets                       = ["subnet-12345678"]
    deploy_nomad_server_instances = true
    server_machine_type           = "m5.xlarge"
    server_disk_size_gb           = 50
    aws_region                    = "us-east-1"
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
    basename                      = "test"
    nomad_server_hostname         = "example.com"
    blocked_cidrs                 = ["192.168.1.0/24"]
    dns_server                    = "192.168.0.2"
    nodes                         = 2
    vpc_id                        = "vpc-12345678"
    subnets                       = ["subnet-12345678"]
    deploy_nomad_server_instances = true
    desired_server_instances      = 3
    max_server_instances          = 7
    aws_region                    = "us-east-1"
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
    basename                      = "test"
    nomad_server_hostname         = "example.com"
    blocked_cidrs                 = ["192.168.1.0/24"]
    dns_server                    = "192.168.0.2"
    nodes                         = 2
    vpc_id                        = "vpc-12345678"
    subnets                       = ["subnet-12345678"]
    deploy_nomad_server_instances = true
    aws_region                    = "us-east-1"
  }

  assert {
    condition     = aws_lb.internal_nlb[0].internal == true
    error_message = "Load balancer should be internal"
  }

  assert {
    condition     = aws_lb.internal_nlb[0].load_balancer_type == "network"
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

run "test_server_cve_2026_98432_mitigation_enabled" {
  module {
    source = "./modules/nomad-server-aws"
  }

  variables {
    aws_region                       = "us-east-1"
    vpc_id                           = "vpc-12345678"
    basename                         = "test"
    nomad_server_hostname            = "example.com"
    random_string_suffix             = "abcd1234"
    server_nlb_arn                   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/test/0123456789abcdef"
    apt_helpers                      = file("../shared/scripts/apt-helpers.sh")
    apt_retry_max_attempts           = 5
    cve_2026_98432_helpers           = file("../shared/scripts/cve-2026-98432.sh")
    enable_cve_2026_98432_mitigation = true
  }

  assert {
    condition     = can(regex("(?m)^mitigate_cve_2026_98432$", data.cloudinit_config.nomad_server_user_data.part[0].content))
    error_message = "Server startup script should call the CVE-2026-98432 mitigation when enable_cve_2026_98432_mitigation is true"
  }

  assert {
    condition     = strcontains(data.cloudinit_config.nomad_server_user_data.part[0].content, "mitigate_cve_2026_98432() {")
    error_message = "Server startup script should define the CVE-2026-98432 mitigation it calls"
  }

  assert {
    condition     = can(regex("(?ms)^retry apt-get update$.*^mitigate_cve_2026_98432$.*^retry apt-get install -y nomad=", data.cloudinit_config.nomad_server_user_data.part[0].content))
    error_message = "Server startup script should call the CVE-2026-98432 mitigation after apt-get update and before it installs Nomad"
  }

  assert {
    condition     = can(regex("(?ms)^systemctl enable --now nomad-liveness-check$.*^mitigate_cve_2026_98432$", data.cloudinit_config.nomad_server_user_data.part[0].content))
    error_message = "Server startup script should start the liveness check before the CVE-2026-98432 mitigation. The ASG uses EC2 health checks, so only the liveness check can replace a server whose mitigation fails."
  }

  assert {
    condition     = strcontains(data.cloudinit_config.nomad_server_user_data.part[0].content, "Description=Nomad server liveness check\nAfter=network.target\n")
    error_message = "The server liveness unit should not start after nomad.service. On systemd 249, a Nomad start that keeps failing never ends its start job, so the liveness check would never start."
  }
}

run "test_server_cve_2026_98432_mitigation_disabled" {
  module {
    source = "./modules/nomad-server-aws"
  }

  variables {
    aws_region                       = "us-east-1"
    vpc_id                           = "vpc-12345678"
    basename                         = "test"
    nomad_server_hostname            = "example.com"
    random_string_suffix             = "abcd1234"
    server_nlb_arn                   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/test/0123456789abcdef"
    apt_helpers                      = file("../shared/scripts/apt-helpers.sh")
    apt_retry_max_attempts           = 5
    cve_2026_98432_helpers           = file("../shared/scripts/cve-2026-98432.sh")
    enable_cve_2026_98432_mitigation = false
  }

  assert {
    condition     = !can(regex("(?m)^mitigate_cve_2026_98432$", data.cloudinit_config.nomad_server_user_data.part[0].content))
    error_message = "Server startup script should not call the CVE-2026-98432 mitigation when enable_cve_2026_98432_mitigation is false"
  }

  assert {
    condition     = !strcontains(data.cloudinit_config.nomad_server_user_data.part[0].content, "mitigate_cve_2026_98432() {")
    error_message = "Server startup script should not include the CVE-2026-98432 helper when enable_cve_2026_98432_mitigation is false"
  }
}

run "test_server_user_data_size_limit" {
  variables {
    basename                      = "test"
    nomad_server_hostname         = "example.com"
    blocked_cidrs                 = ["192.168.1.0/24"]
    dns_server                    = "192.168.0.2"
    nodes                         = 2
    vpc_id                        = "vpc-12345678"
    subnets                       = ["subnet-12345678"]
    deploy_nomad_server_instances = true
    aws_region                    = "us-east-1"
  }

  assert {
    condition     = length(module.server[0].launch_template.user_data) <= 20480
    error_message = "Base64 server user data should stay at or under 20480 characters (15 KB decoded). EC2 rejects user data over 16 KB."
  }
}

run "test_server_user_data_over_ec2_limit_fails" {
  command = plan

  module {
    source = "./modules/nomad-server-aws"
  }

  variables {
    aws_region                       = "us-east-1"
    vpc_id                           = "vpc-12345678"
    basename                         = "test"
    nomad_server_hostname            = "example.com"
    random_string_suffix             = "abcd1234"
    server_nlb_arn                   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/test/0123456789abcdef"
    apt_helpers                      = file("../shared/scripts/apt-helpers.sh")
    apt_retry_max_attempts           = 5
    cve_2026_98432_helpers           = file("../shared/scripts/cve-2026-98432.sh")
    enable_cve_2026_98432_mitigation = true
    # Hex digests compress poorly, so this adds about 10 KB after gzip.
    tls_cert = join("\n", [for i in range(160) : sha512("server-cert-${i}")])
  }

  expect_failures = [aws_launch_template.nomad-servers]
}
