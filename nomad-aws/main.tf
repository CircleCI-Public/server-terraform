provider "aws" {
  region = var.region
}

resource "random_string" "key_suffix" {
  length  = 8
  special = false
}

resource "aws_key_pair" "ssh_key" {
  count      = var.ssh_key != null ? 1 : 0
  key_name   = "circleci-server-nomad-ssh-key-${random_string.key_suffix.result}"
  public_key = var.ssh_key
}

data "aws_ami" "ubuntu_focal" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

module "nomad_tls" {
  source                = "../shared/modules/tls"
  nomad_server_endpoint = var.server_endpoint
  count                 = var.enable_mtls ? 1 : 0
}

locals {
  # Creates the Nomad Security Group(SG) list for the Instances.
  # Will include SSH SG if var.ssh_key is not null.
  nomad_security_groups = compact(list(
    aws_security_group.nomad_sg.id,
    var.ssh_key != null ? aws_security_group.ssh_sg[0].id : "",
  ))
}

data "cloudinit_config" "nomad_user_data" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = templatefile(
      "${path.module}/template/nomad-startup.sh.tpl",
      {
        nomad_server_endpoint = var.server_endpoint
        client_tls_cert       = var.enable_mtls ? module.nomad_tls[0].nomad_client_cert : ""
        client_tls_key        = var.enable_mtls ? module.nomad_tls[0].nomad_client_key : ""
        tls_ca                = var.enable_mtls ? module.nomad_tls[0].nomad_tls_ca : ""
        blocked_cidrs         = var.blocked_cidrs
        dns_server            = var.dns_server
      }
    )
  }
}

resource "aws_instance" "nomad_client" {
  count                  = var.nodes
  ami                    = data.aws_ami.ubuntu_focal.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet
  vpc_security_group_ids = length(var.security_group_id) != 0 ? var.security_group_id : local.nomad_security_groups
  key_name               = var.ssh_key != null ? aws_key_pair.ssh_key[0].id : null
  user_data_base64       = data.cloudinit_config.nomad_user_data.rendered

  root_block_device {
    volume_type = var.volume_type
    volume_size = "100"
  }

  tags = {
    Name = "${var.basename}-nomad-client-${count.index}"
    team = "server"
  }
}
