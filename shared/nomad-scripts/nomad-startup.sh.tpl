#!/bin/bash

# One of 'AWS' or 'GCP'. Value passed into template
export CLOUD_PROVIDER=${cloud_provider}

# Prefix identifier used across all of Server install. Value pased into
# template
export BASE_NAME=${basename}

PRIVATE_IP="$(hostname --ip-address)"
export PRIVATE_IP

export DEBIAN_FRONTEND=noninteractive
UNAME="$(uname -r)"
export UNAME

# In GCP, start up scripts are run outside of cloud-init. This means we
# must wait on cloud init to finish before querying it. If we're running
# on AWS, this script is part of the cloud-init 'config' stage, so we
# can already query `local_hosname` without delay.
if [ "$CLOUD_PROVIDER" == "GCP" ]; then
    cloud-init status --wait
fi
INSTANCE_ID=$(cloud-init query local_hostname)
export INSTANCE_ID

echo "-------------------------------------------"
echo "     Performing System Updates"
echo "-------------------------------------------"
apt-get update && apt-get -y upgrade

echo "--------------------------------------"
echo "        Installing NTP"
echo "--------------------------------------"
apt-get install -y ntp

echo "--------------------------------------"
echo "        Installing Docker"
echo "--------------------------------------"
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get install -y "linux-image-$UNAME"
apt-get update
apt-get -y install docker-ce=5:18.09.1~3-0~ubuntu-xenial

# force docker to use userns-remap to mitigate CVE 2019-5736
apt-get -y install jq
mkdir -p /etc/docker
[ -f /etc/docker/daemon.json ] || echo '{}' > /etc/docker/daemon.json
tmp=$(mktemp)
cp /etc/docker/daemon.json /etc/docker/daemon.json.orig
jq '.["userns-remap"]="default"' /etc/docker/daemon.json > "$tmp" && mv "$tmp" /etc/docker/daemon.json
echo 'export no_proxy="true"' >> /etc/default/docker
service docker restart
sleep 5

echo "--------------------------------------"
echo "         Installing nomad"
echo "--------------------------------------"
apt-get install -y zip
curl -o nomad.zip https://releases.hashicorp.com/nomad/0.11.3/nomad_0.11.3_linux_amd64.zip
unzip nomad.zip
mv nomad /usr/bin

echo "--------------------------------------"
echo "       Installling TLS certs"
echo "--------------------------------------"
mkdir -p /etc/ssl/nomad
cat <<EOT > /etc/ssl/nomad/cert.pem
${client_tls_cert}
EOT
cat <<EOT > /etc/ssl/nomad/key.pem
${client_tls_key}
EOT
cat <<EOT > /etc/ssl/nomad/ca.pem
${tls_ca}
EOT

echo "--------------------------------------"
echo "      Creating config.hcl"
echo "--------------------------------------"

mkdir -p /etc/nomad
cat <<EOT > /etc/nomad/config.hcl
log_level = "DEBUG"
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
    server_join = {
        retry_join = ["nomad.$${BASE_NAME}.circleci.internal:4647"]
    }
    node_class = "linux-64bit"
    options = {"driver.raw_exec.enable" = "1"}
}
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

echo "--------------------------------------"
echo "      Creating nomad.conf"
echo "--------------------------------------"
cat <<EOT > /etc/systemd/system/nomad.service
[Unit]
Description="nomad"
[Service]
Restart=always
RestartSec=30
TimeoutStartSec=1m
ExecStart=/usr/bin/nomad agent -config /etc/nomad/config.hcl
[Install]
WantedBy=multi-user.target
EOT

cat <<EOT > /configure-nomad.sh
#!/bin/bash
for i in {1..6}; do
  if [ ! -f /etc/nomad/config.hcl ]; then
    echo "config.hcl file not found, waiting for nomad to create it..."
    sleep 5
  else
    break
  fi
done
sed -i "s/    servers =.*/    servers = [\"\$${nomad_server}:4647\"]/g" /etc/nomad/config.hcl
sed -i "s/    retry_join =.*/    retry_join = [\"\$${nomad_server}:4647\"]/g" /etc/nomad/config.hcl
service nomad restart
EOT
chmod +x /configure-nomad.sh
echo "--------------------------------------"
echo "   Creating ci-privileged network"
echo "--------------------------------------"
docker network create --label keep --driver=bridge --opt com.docker.network.bridge.name=ci-privileged ci-privileged

echo "--------------------------------------"
echo "      Starting Nomad service"
echo "--------------------------------------"
service nomad restart

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

timeout 1m docker pull circleci/docker-gc:1.0
docker rm -f docker-gc || true

# Will return exit 0 if volume already exists
docker volume create docker-gc --label=keep

# --net=host is used to allow the container to talk to the local statsd agent
docker run \
  --rm \
  --interactive \
  --name "docker-gc" \
  --privileged \
  --net=host \
  --userns=host \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume /var/lib/docker:/var/lib/docker:ro \
  --volume docker-gc:/state \
  "circleci/docker-gc:1.0" \
  -threshold "1000 KB"
EOT
chown root:root /etc/docker-gc-start.rc
chmod 0755 /etc/docker-gc-start.rc

cat <<EOT > /usr/local/sbin/start-units.sh
#!/bin/bash

systemctl enable docker-gc.service
systemctl start docker-gc.service
EOT
chown root:root /usr/local/sbin/start-units.sh
chmod 0755 /usr/local/sbin/start-units.sh

echo "--------------------------------------"
echo "  Start Docker Garbage Collection"
echo "--------------------------------------"
/usr/local/sbin/start-units.sh

echo "--------------------------------------"
echo "  Securing Docker network interfaces"
echo "--------------------------------------"
docker_chain="DOCKER-USER"
/sbin/iptables --wait --insert $docker_chain 5 -i docker+ --destination "10.0.0.0/8" --jump DROP
/sbin/iptables --wait --insert $docker_chain 6 -i br+ --destination "10.0.0.0/8" --jump DROP