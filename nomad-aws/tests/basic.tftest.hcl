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
  }

  assert {
    condition = anytrue([
      for ingress in aws_security_group.nomad_sg.ingress :
      ingress.from_port == 64535 && ingress.to_port == 65535
    ])
    error_message = "Nomad SG should allow retry-with-ssh port range 64535-65535"
  }

  assert {
    condition = anytrue([
      for ingress in aws_security_group.nomad_traffic_sg.ingress :
      ingress.from_port == 4646 && ingress.to_port == 4648
    ])
    error_message = "Nomad traffic SG should allow Nomad ports 4646-4648"
  }
}

run "test_ssh_key_conditional" {
  variables {
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 2
    vpc_id                = "vpc-12345678"
    ssh_key               = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."
  }

  assert {
    condition     = length(aws_key_pair.ssh_key) == 1
    error_message = "SSH key pair should be created when ssh_key is provided"
  }

  assert {
    condition     = length(aws_security_group.ssh_sg) == 1
    error_message = "SSH security group should be created when ssh_key is provided"
  }

  assert {
    condition = anytrue([
      for ingress in aws_security_group.ssh_sg[0].ingress :
      ingress.from_port == 22 && ingress.to_port == 22
    ])
    error_message = "SSH security group should allow port 22"
  }
}
