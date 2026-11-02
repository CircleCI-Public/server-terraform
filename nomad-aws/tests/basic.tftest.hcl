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

  mock_resource "aws_iam_role" {
    defaults = {
      id  = "nomad-clients-role"
      arn = "arn:aws:iam::123456789012:role/nomad-clients-role"
    }
  }

  mock_resource "aws_iam_instance_profile" {
    defaults = {
      id  = "nomad-clients-profile"
      arn = "arn:aws:iam::123456789012:instance-profile/nomad-clients-profile"
    }
  }

  mock_resource "aws_iam_policy" {
    defaults = {
      id  = "policy-12345678"
      arn = "arn:aws:iam::123456789012:policy/nomad-describe-ec2-policy"
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

run "test_ca_distrust_order" {
  variables {
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 2
    vpc_id                = "vpc-12345678"
    aws_region            = "us-east-1"
    basename              = "cci-nomad"
  }

  assert {
    condition     = can(regex("(?ms)^retry apt-get update$.*^distrust_compromised_ca_roots$", data.cloudinit_config.nomad_user_data.part[0].content))
    error_message = "distrust_compromised_ca_roots should run after apt-get update"
  }

  assert {
    condition     = length(regexall("(?m)^[^#\\n]*\\b(?:curl|wget)\\b[^\\n]*https://", split("\ndistrust_compromised_ca_roots\n", data.cloudinit_config.nomad_user_data.part[0].content)[0])) == 0
    error_message = "Nothing should fetch over HTTPS before distrust_compromised_ca_roots runs"
  }

  assert {
    condition     = strcontains(data.cloudinit_config.nomad_user_data.part[0].content, "\ndistrust_compromised_ca_roots() {")
    error_message = "The startup script calls distrust_compromised_ca_roots, so it must also define it"
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

  assert {
    condition     = length(aws_autoscaling_group.clients_asg.suspended_processes) == 0
    error_message = "ASG should not suspend any process by default"
  }
}

run "test_suspend_az_rebalance" {
  variables {
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 3
    max_nodes             = 10
    vpc_id                = "vpc-12345678"
    aws_region            = "us-east-1"
    basename              = "cci-nomad"
    suspend_az_rebalance  = true
  }

  assert {
    condition     = contains(aws_autoscaling_group.clients_asg.suspended_processes, "AZRebalance")
    error_message = "ASG should have AZ rebalancing suspended when suspend_az_rebalance is true"
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

run "test_cve_2026_98432_mitigation_enabled_by_default" {
  variables {
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 2
    vpc_id                = "vpc-12345678"
    aws_region            = "us-east-1"
    basename              = "cci-nomad"
  }

  assert {
    condition     = can(regex("(?m)^mitigate_cve_2026_98432$", data.cloudinit_config.nomad_user_data.part[0].content))
    error_message = "Startup script should call the CVE-2026-98432 mitigation by default"
  }

  assert {
    condition     = strcontains(data.cloudinit_config.nomad_user_data.part[0].content, "mitigate_cve_2026_98432() {")
    error_message = "Startup script should define the CVE-2026-98432 mitigation it calls"
  }

  assert {
    condition = can(regex(
      "(?ms)^retry apt-get update$.*^mitigate_cve_2026_98432$",
      regex("(?s)^(.*?)\nif \\[ \"(?:true|false)\" [!=]= \"true\" \\]; then\n", data.cloudinit_config.nomad_user_data.part[0].content)[0]
    ))
    error_message = "Startup script should call the CVE-2026-98432 mitigation after apt-get update and before the first Docker or Podman branch, so both runtime paths run it"
  }

  # No server is deployed in this run, so check the module call in server.tf.
  assert {
    condition = alltrue([
      can(regex("(?m)^\\s*cve_2026_98432_helpers\\s*=\\s*local\\.cve_2026_98432_helpers\\s*$", file("server.tf"))),
      can(regex("(?m)^\\s*enable_cve_2026_98432_mitigation\\s*=\\s*var\\.enable_cve_2026_98432_mitigation\\s*$", file("server.tf"))),
    ]) && var.enable_cve_2026_98432_mitigation
    error_message = "The root module should pass the stripped CVE-2026-98432 helper and the flag to the server module unchanged"
  }
}

run "test_liveness_check_starts_after_nomad" {
  variables {
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 2
    vpc_id                = "vpc-12345678"
    aws_region            = "us-east-1"
    basename              = "cci-nomad"
  }

  assert {
    condition     = strcontains(data.cloudinit_config.nomad_user_data.part[0].content, "Description=Nomad client liveness check\nAfter=network.target nomad.service\n")
    error_message = "The client liveness unit should start after nomad.service, so that a check at boot does not find Nomad still starting"
  }
}

run "test_embedded_scripts_ship_verbatim" {
  variables {
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 2
    vpc_id                = "vpc-12345678"
    aws_region            = "us-east-1"
    basename              = "cci-nomad"
  }

  assert {
    condition     = strcontains(data.cloudinit_config.nomad_user_data.part[0].content, "cat <<'NOMAD_SET_UNHEALTHY_EOF' > /usr/local/bin/nomad-set-unhealthy.sh\n${file("template/nomad-set-unhealthy.sh")}\nNOMAD_SET_UNHEALTHY_EOF\n")
    error_message = "Startup script should write nomad-set-unhealthy.sh verbatim from a quoted heredoc"
  }

  assert {
    condition     = strcontains(data.cloudinit_config.nomad_user_data.part[0].content, "cat <<'NOMAD_LIVENESS_CHECK_EOF' > /usr/local/bin/nomad-liveness-check.sh\n${templatefile("template/nomad-liveness-check.sh.tpl", { external_nomad_server = false, use_podman = false })}\nNOMAD_LIVENESS_CHECK_EOF\n")
    error_message = "Startup script should write nomad-liveness-check.sh verbatim from a quoted heredoc"
  }

  assert {
    condition = alltrue([
      for delimiter in ["NOMAD_SET_UNHEALTHY_EOF", "NOMAD_LIVENESS_CHECK_EOF"] :
      length(regexall("[^\\x00-\\x7F]", regex("(?s)<<'${delimiter}' [^\n]*\n(.*?)\n${delimiter}\n", data.cloudinit_config.nomad_user_data.part[0].content)[0])) == 0
    ])
    error_message = "The scripts that the startup script embeds should be ASCII only, because cloud-init rewrites other characters in user data"
  }
}

run "test_helpers_ship_without_comment_lines" {
  variables {
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 2
    vpc_id                = "vpc-12345678"
    aws_region            = "us-east-1"
    basename              = "cci-nomad"
  }

  assert {
    condition     = !can(regex("(?m)^[[:space:]]*# (CVE-2026-98432 mitigation for the Nomad|Shared apt/dpkg helpers)", data.cloudinit_config.nomad_user_data.part[0].content))
    error_message = "The shell helpers should ship without their comment lines, to fit in EC2 user data"
  }

  assert {
    condition     = length(regexall("(?m)^[[:space:]]*#( |$)", local.apt_helpers)) == 0 && length(regexall("(?m)^[[:space:]]*#( |$)", local.cve_2026_98432_helpers)) == 0
    error_message = "The stripped shell helpers should have no comment lines left"
  }

  assert {
    condition = alltrue([
      for line in [
        "ip protocol tcp ip hdrlength != 5 counter drop",
        "ExecStartPre=/bin/sh -c '/usr/sbin/nft -f /etc/circleci/cve-2026-98432.nft || ",
        "ExecStartPost=/usr/sbin/nft -f /etc/circleci/cve-2026-98432.nft",
        "WantedBy=sysinit.target",
      ] : strcontains(data.cloudinit_config.nomad_user_data.part[0].content, line)
    ])
    error_message = "Comment stripping should keep the heredoc bodies of the CVE-2026-98432 helper"
  }
}

run "test_cve_2026_98432_mitigation_disabled" {
  variables {
    nomad_server_hostname            = "example.com"
    blocked_cidrs                    = ["192.168.1.0/24"]
    dns_server                       = "192.168.0.2"
    nodes                            = 2
    vpc_id                           = "vpc-12345678"
    aws_region                       = "us-east-1"
    basename                         = "cci-nomad"
    enable_cve_2026_98432_mitigation = false
  }

  assert {
    condition     = !can(regex("(?m)^mitigate_cve_2026_98432$", data.cloudinit_config.nomad_user_data.part[0].content))
    error_message = "Startup script should not call the CVE-2026-98432 mitigation when enable_cve_2026_98432_mitigation is false"
  }

  assert {
    condition     = !strcontains(data.cloudinit_config.nomad_user_data.part[0].content, "mitigate_cve_2026_98432() {")
    error_message = "Startup script should not include the CVE-2026-98432 helper when enable_cve_2026_98432_mitigation is false"
  }
}

run "test_user_data_size_limit" {
  variables {
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 2
    vpc_id                = "vpc-12345678"
    aws_region            = "us-east-1"
    basename              = "cci-nomad"
  }

  assert {
    condition     = length(data.cloudinit_config.nomad_user_data.rendered) <= 20480
    error_message = "Base64 user data should stay at or under 20480 characters (15 KB decoded) with these small inputs. EC2 rejects user data over 16 KB. Real inputs are larger, and each RSA-4096 certificate in custom_ca_cert adds about 1.5 KB."
  }
}

run "test_user_data_over_ec2_limit_fails" {
  command = plan

  # Fixed TLS values make the user data known at plan time.
  override_module {
    target = module.nomad_tls
    outputs = {
      nomad_server_cert = "CERT"
      nomad_server_key  = "KEY"
      nomad_client_cert = "CERT"
      nomad_client_key  = "KEY"
      nomad_tls_ca      = "CA"
    }
  }

  variables {
    nomad_server_hostname = "example.com"
    blocked_cidrs         = ["192.168.1.0/24"]
    dns_server            = "192.168.0.2"
    nodes                 = 2
    vpc_id                = "vpc-12345678"
    aws_region            = "us-east-1"
    basename              = "cci-nomad"
    # Hex digests compress poorly, so this adds about 10 KB after gzip.
    custom_ca_cert = join("\n", [for i in range(160) : sha512("custom-ca-${i}")])
  }

  expect_failures = [aws_launch_template.nomad_clients]
}