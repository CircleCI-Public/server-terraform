#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
UNAME="$(uname -r)"
export UNAME

export aws_instance_metadata_url="http://169.254.169.254"
export TOKEN="$(curl -X PUT "$aws_instance_metadata_url/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 180")"
export PUBLIC_IP="$(curl -H "X-aws-ec2-metadata-token: $TOKEN" $aws_instance_metadata_url/latest/meta-data/public-ipv4)"
export PRIVATE_IP="$(curl -H "X-aws-ec2-metadata-token: $TOKEN" $aws_instance_metadata_url/latest/meta-data/local-ipv4)"

echo "PUBLIC_IP: $PUBLIC_IP"
echo "PRIVATE_IP: $PRIVATE_IP"

INSTANCE_ID=$(cloud-init query local_hostname)
export INSTANCE_ID
echo "INSTANCE_ID: $INSTANCE_ID"

# Setting up PS1
# PS1 = ubuntu@ip-172-16-4-15-client
echo 'export PS1="\[\033[01;32m\]\u@\h-client\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /home/ubuntu/.bashrc

echo "--------------------------------------"
echo "      Setting environment variables"
echo "--------------------------------------"
echo 'export NOMAD_CACERT=/etc/ssl/nomad/ca.pem' >> /etc/environment
echo 'export NOMAD_CLIENT_CERT=/etc/ssl/nomad/client.pem' >> /etc/environment
echo 'export NOMAD_CLIENT_KEY=/etc/ssl/nomad/key.pem' >> /etc/environment

[ "${external_nomad_server}" == "true" ] && SCHEME="https" || SCHEME="http"
echo "export NOMAD_ADDR=$SCHEME://localhost:4646" >> /etc/environment

source /etc/environment
env | grep "NOMAD_"

retry() {
    local -r -i max_attempts=5
    local -i attempt_num=1

    until "$@"; do
        if (( attempt_num == max_attempts )); then
            echo "Attempt $attempt_num failed and there are no more attempts left!"
            exit 1
        else
            echo "Attempt $attempt_num failed! Trying again..."
            ((attempt_num++))
            sleep 5
        fi
    done
}

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
apt-get update && retry apt-get -y upgrade

echo "--------------------------------------"
echo "        Installing NTP"
echo "--------------------------------------"
retry apt-get install -y ntp

echo "--------------------------------------"
echo "        Installing Docker"
echo "--------------------------------------"
retry apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
retry apt-get install -y "linux-image-$UNAME"
apt-get update
retry apt-get -y install docker-ce=5:28.1.1-1~ubuntu.22.04~jammy \
                   docker-ce-cli=5:28.1.1-1~ubuntu.22.04~jammy \
                   jq

# force docker to use userns-remap to mitigate CVE 2019-5736
mkdir -p /etc/docker
[ -f /etc/docker/daemon.json ] || echo '{}' > /etc/docker/daemon.json
tmp=$(mktemp)
cp /etc/docker/daemon.json /etc/docker/daemon.json.orig

echo "--------------------------------------"
echo "   Creating docker daemon file"
echo "--------------------------------------"

cat <<EOT > /etc/docker/daemon.json
{
    "userns-remap": "default",
    "default-address-pools": [
        { "base":"${docker_network_cidr}" , "size":24 }
    ]
}
EOT

echo 'export no_proxy="true"' >> /etc/default/docker

%{ if custom_ca_cert != "" ~}
echo "--------------------------------------"
echo "   Installing Custom CA Certificate"
echo "--------------------------------------"
cat <<EOT > /usr/local/share/ca-certificates/circleci-custom-ca.crt
${custom_ca_cert}
EOT
update-ca-certificates
echo "Custom CA certificate installed successfully"
%{ endif ~}

service docker restart
sleep 5

echo "--------------------------------------"
echo " Populating /etc/circleci/public-ipv4"
echo "--------------------------------------"
echo "Setting the IPv4 address below in /etc/circleci/public-ipv4."
echo "This address will be used in builds with \"Rebuild with SSH\"."
mkdir -p /etc/circleci
if ! (echo $PUBLIC_IP | grep -qP "^[\d.]+$"); then
    echo $PRIVATE_IP | tee /etc/circleci/public-ipv4
else
    echo $PUBLIC_IP | tee /etc/circleci/public-ipv4
fi

echo "--------------------------------------"
echo "         Installing nomad"
echo "--------------------------------------"
retry sudo apt-get update && \
retry sudo apt-get install wget gpg coreutils
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update && retry sudo apt-get install nomad=${nomad_version}
sudo nomad version


echo "--------------------------------------"
echo "       Installling TLS certs"
echo "--------------------------------------"
mkdir -p /etc/ssl/nomad
cat <<EOT > /etc/ssl/nomad/client.pem
${client_tls_cert}
EOT
cat <<EOT > /etc/ssl/nomad/key.pem
${client_tls_key}
EOT
cat <<EOT > /etc/ssl/nomad/ca.pem
${tls_ca}
EOT
ls -l /etc/ssl/nomad

echo "--------------------------------------"
echo "      Creating client.hcl"
echo "--------------------------------------"

mkdir -p /etc/nomad
cat <<EOT > /etc/nomad/client.hcl
log_level = "${log_level}"
name = "$INSTANCE_ID"
data_dir = "/opt/nomad"
datacenter = "default"
advertise {
    http = "$PRIVATE_IP"
    rpc = "$PRIVATE_IP"
    serf = "$PRIVATE_IP"
}
client {
    enabled = true
    # Expecting to have DNS record for nomad server(s)
    server_join {
        retry_join = ["${server_retry_join}"]
        retry_max  = 30
        retry_interval = "30s"
    }
    node_class = "linux-64bit"
}
plugin "raw_exec" {
  config {
    enabled = true
  }
}
telemetry {
    collection_interval = "1s"
    disable_hostname = true
    prometheus_metrics = true
    publish_allocation_metrics = true
    publish_node_metrics = true
}
EOT

if [ "${external_nomad_server}" == "true" ]; then
cat <<EOT >> /etc/nomad/client.hcl
tls {
    http = true
    rpc  = true
    # This verifies the CN ([role].[region].nomad) in the certificate,
    # not the hostname or DNS name of the of the remote party.
    # https://learn.hashicorp.com/tutorials/nomad/security-enable-tls?in=nomad/transport-security#node-certificates
    verify_server_hostname = true
    verify_https_client = false
    ca_file   = "/etc/ssl/nomad/ca.pem"
    cert_file = "/etc/ssl/nomad/client.pem"
    key_file  = "/etc/ssl/nomad/key.pem"
}
EOT
else
cat <<EOT >> /etc/nomad/client.hcl
tls {
    http = false
    rpc  = true
    # This verifies the CN ([role].[region].nomad) in the certificate,
    # not the hostname or DNS name of the of the remote party.
    # https://learn.hashicorp.com/tutorials/nomad/security-enable-tls?in=nomad/transport-security#node-certificates
    verify_server_hostname = true
    verify_https_client = false
    ca_file   = "/etc/ssl/nomad/ca.pem"
    cert_file = "/etc/ssl/nomad/client.pem"
    key_file  = "/etc/ssl/nomad/key.pem"
}
EOT
fi

ls -l /etc/nomad

echo "--------------------------------------"
echo "      Creating nomad.service"
echo "--------------------------------------"
cat <<EOT > /etc/systemd/system/nomad.service
[Unit]
Description="nomad"
[Service]
Environment="NOMAD_CACERT=/etc/ssl/nomad/ca.pem"
Environment="NOMAD_CLIENT_CERT=/etc/ssl/nomad/client.pem"
Environment="NOMAD_CLIENT_KEY=/etc/ssl/nomad/key.pem"
Environment="NOMAD_ADDR=$NOMAD_ADDR"
Restart=always
RestartSec=30
TimeoutStartSec=1m
ExecStart=/usr/bin/nomad agent -config /etc/nomad/client.hcl
[Install]
WantedBy=multi-user.target
EOT

echo "--------------------------------------"
echo "   Creating ci-privileged network"
echo "--------------------------------------"
docker network create --label keep --driver=bridge --opt com.docker.network.bridge.name=ci-privileged ci-privileged

echo "--------------------------------------"
echo "      Starting Nomad service"
echo "--------------------------------------"
systemctl enable --now nomad
systemctl status nomad


echo "--------------------------------------"
echo "  Set Up Docker Garbage Collection"
echo "--------------------------------------"

cat <<EOT > /etc/systemd/system/docker-gc.service
[Unit]
Description=Docker garbage collector
[Service]
Type=simple
Restart=always
ExecStart=/etc/docker-gc-start.rc
ExecStop=/bin/bash -c "docker rm -f docker-gc || true"
[Install]
WantedBy=cloud-init.target
EOT
chown root:root /etc/systemd/system/docker-gc.service
chmod 0644 /etc/systemd/system/docker-gc.service

cat <<EOT > /etc/docker-gc-start.rc
#!/bin/bash
set -euo pipefail
timeout 1m docker pull circleci/docker-gc:2.0
docker rm -f docker-gc || true
# Will return exit 0 if volume already exists
docker volume create docker-gc --label=keep
# --net=host is used to allow the container to talk to the local statsd agent
docker run \
  --rm \
  --interactive \
  --name "docker-gc" \
  --privileged \
  --userns=host \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume /var/lib/docker:/var/lib/docker:ro \
  --volume docker-gc:/state \
  --network=ci-privileged \
  --network-alias=docker-gc.internal.circleci.com \
  "circleci/docker-gc:2.0" \
  -threshold-percent 50 \
  -o11y-format text
EOT
chmod 0700 /etc/docker-gc-start.rc

echo "--------------------------------------"
echo "  Start Docker Garbage Collection"
echo "--------------------------------------"
systemctl enable --now docker-gc
systemctl status docker-gc

echo "--------------------------------------"
echo "  Securing Docker network interfaces"
echo "--------------------------------------"
docker_chain="DOCKER-USER"
# Blocking meta-data endpoint access
/sbin/iptables --wait --insert $docker_chain -i docker+ --destination "169.254.0.0/16" --jump DROP
/sbin/iptables --wait --insert $docker_chain -i br-+ --destination "169.254.0.0/16" --jump DROP
# Blocking internal cluster resources
%{ for cidr_block in blocked_cidrs ~}
/sbin/iptables --wait --insert $docker_chain -i docker+ --destination "${cidr_block}" --jump DROP
/sbin/iptables --wait --insert $docker_chain -i br+ --destination "${cidr_block}" --jump DROP
%{ endfor ~}
/sbin/iptables --wait --insert $docker_chain 1 -i br+ --destination "${dns_server}" -p tcp --dport 53 --jump RETURN
/sbin/iptables --wait --insert $docker_chain 2 -i br+ --destination "${dns_server}" -p udp --dport 53 --jump RETURN
