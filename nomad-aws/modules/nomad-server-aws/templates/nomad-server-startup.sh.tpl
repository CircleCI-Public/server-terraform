#!/bin/bash
PRIVATE_IP="$(hostname --ip-address | awk '{print $1}')"
export PRIVATE_IP
echo $PRIVATE_IP

export DEBIAN_FRONTEND=noninteractive
UNAME="$(uname -r)"
export UNAME

INSTANCE_ID=$(cloud-init query local_hostname)
export INSTANCE_ID

echo "----------------------------------------"
echo "        Tuning kernel parameters"
echo "----------------------------------------"
if [ -f /sys/block/nvme0n1/queue/scheduler ] && grep -q 'mq-deadline' /sys/block/nvme0n1/queue/scheduler
then
    echo 'mq-deadline' > /sys/block/nvme0n1/queue/scheduler
    echo 'ACTION=="add|change", KERNEL=="nvme0n1", ATTR{queue/scheduler}="mq-deadline"' > /etc/udev/rules.d/99-circleci-io-scheduler.rules
    update-grub
fi

echo "-------------------------------------------"
echo "     Performing System Updates"
echo "-------------------------------------------"
apt-get update && apt-get -y upgrade

echo "--------------------------------------"
echo "        Installing NTP"
echo "--------------------------------------"
apt-get install -y ntp

echo "--------------------------------------"
echo "Installing Nomad"
echo "--------------------------------------"
apt-get update && apt-get install wget gpg coreutils
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install nomad

echo "--------------------------------------"
echo "       Installling TLS certs"
echo "--------------------------------------"
mkdir -p /etc/ssl/nomad
cat <<-EOT > /etc/ssl/nomad/cert.pem
${tls_cert}
EOT
cat <<-EOT > /etc/ssl/nomad/key.pem
${tls_key}
EOT
cat <<-EOT > /etc/ssl/nomad/ca.pem
${tls_ca}
EOT

echo "--------------------------------------"
echo "      Creating server.hcl"
echo "--------------------------------------"

mkdir -p /etc/nomad/
mkdir -p /etc/nomad.d/
cat <<EOT > /etc/nomad.d/server.hcl
server {
    enabled = true
    bootstrap_expect = ${bootstrap_expect}
    server_join {
        retry_join = ["provider="aws" tag_key=${tag_key} tag_value=${tag_value} addr_type=${addr_type} region=${region}"]
        retry_max  = 30
        retry_interval = "30s"
    }
}

consul {
    auth = "no:consul"
    auto_advertise = false
    client_auto_join = false
    server_auto_join = false
}

log_level = "DEBUG"
leave_on_interrupt = false
leave_on_terminate = true # Leave cluster on SIGTERM
disable_update_check = true 
data_dir = "/var/lib/nomad/" 

advertise {
    http = "$PRIVATE_IP:4646" 
    rpc  = "$PRIVATE_IP:4647"
    serf = "$PRIVATE_IP:4648" 
}
client {
  enabled = false
}
EOT

if [ "${tls_cert}" ]; then
cat <<-EOT >> /etc/nomad.d/server.hcl
tls {
    http = false
    rpc  = true
    # This verifies the CN ([role].[region].nomad) in the certificate,
    # not the hostname or DNS name of the of the remote party.
    # https://learn.hashicorp.com/tutorials/nomad/security-enable-tls?in=nomad/transport-security#node-certificates
    verify_server_hostname = true
    ca_file   = "/etc/ssl/nomad/ca.pem"
    cert_file = "/etc/ssl/nomad/cert.pem"
    key_file  = "/etc/ssl/nomad/key.pem"
}
EOT
fi

echo "--------------------------------------"
echo "      Starting Nomad service"
echo "--------------------------------------"
systemctl enable --now nomad