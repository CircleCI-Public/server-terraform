#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# if tmpfs is found then cgroups v1 has been configured to be used and the system does not need to be re-initialized
sudo stat -fc %T /sys/fs/cgroup/ | grep "tmpfs" && exit 0 || echo "Cgroups V2 detected, running system initialization"

log() {
	msg=$1
	color="\e[1;36m" # Bold, Cyan
	reset="\e[0m"
	#echo -e "$${color}$${msg}$${reset}"
	echo -e "$${msg}"
}

tune_io_scheduler() {
	log "--------------------------------------"
	log "Tuning kernel IO scheduler if needed"
	log "--------------------------------------"
	if [ -f /sys/block/nvme0n1/queue/scheduler ] && grep -q 'mq-deadline' /sys/block/nvme0n1/queue/scheduler
	then
		echo 'mq-deadline' > /sys/block/nvme0n1/queue/scheduler
		echo 'ACTION=="add|change", KERNEL=="nvme0n1", ATTR{queue/scheduler}="mq-deadline"' > /etc/udev/rules.d/99-circleci-io-scheduler.rules
	update-grub
	fi
}

system_update() {
	log "--------------------------------------"
	log "Updating system"
	log "--------------------------------------"
	apt-get update && apt-get -y upgrade
}

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

install() {
	package=$@
	log "--------------------------------------"
	log "Installing $${package}"
	log "--------------------------------------"
	retry apt-get install -y $${package}
}

add_docker_repo() {
	apt-get install -y apt-transport-https ca-certificates curl software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	install "linux-image-$(uname -r)"
	apt-get update
}

enabled_docker_userns() {
	# Enabled user namespacing in Docker (root in container != root on host)
	# Mitigates CVE 2019-5736
	[ -f /etc/docker/daemon.json ] || echo '{}' > /etc/docker/daemon.json
	tmp=$(mktemp)
	cp /etc/docker/daemon.json /etc/docker/daemon.json.orig

	echo "--------------------------------------"
	echo "   Creating docker daemon file"
	echo "--------------------------------------"

	cat <<-EOT > /etc/docker/daemon.json
	{
		"userns-remap": "default",
		"default-address-pools": [
			{ "base":"${docker_network_cidr}" , "size":24 }
		]
	}
	EOT
	echo 'export no_proxy="true"' >> /etc/default/docker

	systemctl restart docker
}

configure_circleci() {
	log "--------------------------------------"
	log "Configuring CircleCI"
	log "--------------------------------------"
	public_ip="$(curl -H 'Metadata-Flavor: Google' http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)"
	private_ip="$(hostname --ip-address)"
	if ! (echo $public_ip | grep -qP "^[\d.]+$"); then
		echo "Setting the IPv4 address below in /etc/circleci/public-ipv4."
		echo "This address will be used in builds with \"Rebuild with SSH\"."
		mkdir -p /etc/circleci
		echo $private_ip | tee /etc/circleci/public-ipv4
	fi
}

install_nomad() {
	log "--------------------------------------"
	log "Installing Nomad"
	log "--------------------------------------"
	sudo apt-get update && \
	sudo apt-get install wget gpg coreutils
	wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
	echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
	sudo apt-get update && sudo apt-get install nomad=${nomad_version}

	nomad --version || ( echo "Nomad failed to install" && exit 1 )
}

configure_nomad() {
	log "--------------------------------------"
	log "Installing TLS Certificates"
	log "--------------------------------------"

	mkdir -p /etc/nomad/ssl
	chmod 0700 /etc/nomad/ssl
	cat <<-EOT > /etc/nomad/ssl/cert.pem
	${client_tls_cert}
	EOT
	cat <<-EOT > /etc/nomad/ssl/key.pem
	${client_tls_key}
	EOT
	cat <<-EOT > /etc/nomad/ssl/ca.pem
	${tls_ca}
	EOT

	log "Setting nomad configuration"
	mkdir -p /etc/nomad
	cat <<-EOT > /etc/nomad/config.hcl
	log_level = "DEBUG"
	name = "$(hostname)"
	data_dir = "/opt/nomad"
	datacenter = "default"
	advertise {
	  http = "$(hostname --ip-address)"
	  rpc = "$(hostname --ip-address)"
	  serf = "$(hostname --ip-address)"
	}
	client {
	  enabled = true
	EOT
	# Expecting to have DNS record for nomad server(s)
	if [ "${add_server_join}" ]; then
	cat <<-EOT >> /etc/nomad/config.hcl
	  server_join = {
		retry_join = ["${server_retry_join}"]
	  }
	EOT
	fi
	cat <<-EOT >> /etc/nomad/config.hcl
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

	if [ "${client_tls_cert}" ]; then
		cat <<-EOT >> /etc/nomad/config.hcl
		tls {
		  http = false
		  rpc  = true
		  # This verifies the CN ([role].[region].nomad) in the certificate,
		  # not the hostname or DNS name of the of the remote party.
		  # https://learn.hashicorp.com/tutorials/nomad/security-enable-tls?in=nomad/transport-security#node-certificates
		  verify_server_hostname = true
		  ca_file	= "/etc/nomad/ssl/ca.pem"
		  cert_file = "/etc/nomad/ssl/cert.pem"
		  key_file	= "/etc/nomad/ssl/key.pem"
		}
		EOT
	fi

	log "Writing nomad systemd unit"
	cat <<-EOT > /etc/systemd/system/nomad.service
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

	log "Starting up nomad" 
	systemctl enable --now nomad
}

create_ci_network() {
	docker network create \
	   --label keep \
	   --driver=bridge \
	   --opt com.docker.network.bridge.name=ci-privileged \
	   ci-privileged
}

setup_docker_gc() {
	log "--------------------------------------"
	log "setting up Docker garbage collection"
	log "--------------------------------------"

	cat <<-EOT > /etc/systemd/system/docker-gc.service
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
	chmod 0600 /etc/systemd/system/docker-gc.service

	cat <<-EOT > /etc/docker-gc-start.rc
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
	  -threshold-percent 50
	EOT
	chmod 0700 /etc/docker-gc-start.rc

	systemctl enable --now docker-gc
}

revert_cgroups(){
      sudo sed -i '/^GRUB_CMDLINE_LINUX/ s/"$/ systemd.unified_cgroup_hierarchy=0"/' /etc/default/grub
      sudo update-grub
}

tune_io_scheduler
system_update
add_docker_repo

install ntp
install docker-ce=5:28.1.1-1~ubuntu.22.04~jammy
install docker-ce-cli=5:28.1.1-1~ubuntu.22.04~jammy
install jq

enabled_docker_userns
configure_circleci
install_nomad || exit 1
configure_nomad

create_ci_network
setup_docker_gc

echo "--------------------------------------"
echo "	Securing Docker network interfaces"
echo "--------------------------------------"
docker_chain="DOCKER-USER"
# Blocking meta-data endpoint access
/sbin/iptables --wait --insert $docker_chain 1 -i br+ --destination 169.254.169.254/32 -p tcp --dport 53 --jump RETURN # Allow DNS queries
/sbin/iptables --wait --insert $docker_chain 2 -i br+ --destination 169.254.169.254/32 -p udp --dport 53 --jump RETURN # Allow DNS queries
/sbin/iptables --wait --insert $docker_chain 3 -i docker+ --destination "169.254.0.0/16" --jump DROP
/sbin/iptables --wait --insert $docker_chain 4 -i br-+ --destination "169.254.0.0/16" --jump DROP

# Blocking internal cluster resources
%{ for cidr_block in blocked_cidrs ~}
/sbin/iptables --wait --insert $docker_chain 5 -i docker+ --destination "${cidr_block}" --jump DROP
/sbin/iptables --wait --insert $docker_chain 5 -i br+ --destination "${cidr_block}" --jump DROP
%{ endfor ~}

revert_cgroups
reboot
