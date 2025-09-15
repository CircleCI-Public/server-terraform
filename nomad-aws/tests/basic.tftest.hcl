mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id   = "ami-12345678"
      name = "CircleCIServerNomad-test"
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id         = "vpc-12345678"
      cidr_block = "192.168.0.0/16"
    }
  }

  mock_resource "aws_launch_template" {
    defaults = {
      id   = "lt-12345678"
      name = "test-nomad-clients-template"
    }
  }

  mock_resource "aws_autoscaling_group" {
    defaults = {
      id   = "test-nomad-clients-asg"
      name = "test_circleci_nomad_clients_asg"
    }
  }
}

run "test_launch_template_configuration" {
  variables {
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 2
    vpc_id                = "vpc-12345678"
    instance_type         = "m5.large"
    disk_size_gb          = 100
    aws_region            = "us-east-1"
    basename              = "cci-nomad"
  }

  assert {
    condition     = aws_launch_template.nomad_clients.instance_type == "m5.large"
    error_message = "Launch template should use specified instance type"
  }

  assert {
    condition     = aws_launch_template.nomad_clients.image_id == "ami-12345678"
    error_message = "Launch template should use mocked AMI"
  }

  assert {
    condition     = aws_launch_template.nomad_clients.block_device_mappings[0].ebs[0].volume_size == 100
    error_message = "Launch template should have correct disk size"
  }
}

run "test_autoscaling_group_configuration" {
  variables {
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 3
    max_nodes             = 10
    vpc_id                = "vpc-12345678"
    nomad_auto_scaler     = true
    aws_region            = "us-east-1"
    basename              = "cci-nomad"
  }

  assert {
    condition     = aws_autoscaling_group.clients_asg.desired_capacity == 3
    error_message = "ASG desired capacity should match nodes variable"
  }

  assert {
    condition     = aws_autoscaling_group.clients_asg.max_size == 10
    error_message = "ASG max size should match max_nodes variable"
  }

  assert {
    condition     = aws_autoscaling_group.clients_asg.min_size == 1
    error_message = "ASG min size should be 1 when nomad_auto_scaler is enabled"
  }
}

run "test_security_group_configuration" {
  variables {
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 2
    vpc_id                = "vpc-12345678"
    allowed_ips_retry_ssh = ["10.0.0.0/8"]
    aws_region            = "us-east-1"
    basename              = "cci-nomad"
  }

  assert {
    condition     = aws_security_group_rule.nomad_retry_ssh_ingress.from_port == 64535
    error_message = "From port should be 64535"
  }

  assert {
    condition     = aws_security_group_rule.nomad_retry_ssh_ingress.to_port == 65535
    error_message = "To port should be 65535"
  }

  assert {
    condition     = aws_security_group_rule.nomad_traffic_sg.from_port == 4646
    error_message = "From port should be 4646"
  }

  assert {
    condition     = aws_security_group_rule.nomad_traffic_sg.to_port == 4648
    error_message = "To port should be 4648"
  }
}

run "test_ssh_key_conditional" {
  variables {
    nomad_server_hostname                    = "example.com"
    blocked_cidrs                            = ["192.168.1.0/24"]
    dns_server                               = "192.168.0.2"
    nodes                                    = 2
    vpc_id                                   = "vpc-12345678"
    ssh_key                                  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."
    aws_region                               = "us-east-1"
    basename                                 = "cci-nomad"
    allowed_ips_circleci_server_nomad_access = ["44.0.0.123/32"]
  }

  assert {
    condition     = length(aws_key_pair.ssh_key) == 1
    error_message = "SSH key pair should be created when ssh_key is provided"
  }

  assert {
    condition     = aws_security_group_rule.nomad_ssh_sg[0].to_port == 22
    error_message = "To port should be 22"
  }

  assert {
    condition     = aws_security_group_rule.nomad_ssh_sg[0].from_port == 22
    error_message = "From port should be 22"
  }

  assert {
    condition     = aws_security_group_rule.nomad_ssh_sg[0].cidr_blocks[0] == "44.0.0.123/32"
    error_message = "CIDR blocks should be 44.0.0.123/32"
  }
}

run "test_mtls_configuration" {
  variables {
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 2
    vpc_id                = "vpc-12345678"
    ssh_key               = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."
    aws_region            = "us-east-1"
    basename              = "cci-nomad"
  }

  assert {
    condition     = module.nomad_tls.nomad_client_cert != ""
    error_message = "Nomad Client cert should not be empty"
  }

  assert {
    condition     = module.nomad_tls.nomad_client_key != ""
    error_message = "Nomad Client key should not be empty"
  }

  assert {
    condition     = module.nomad_tls.nomad_tls_ca != ""
    error_message = "Nomad CA should not be empty"
  }
}