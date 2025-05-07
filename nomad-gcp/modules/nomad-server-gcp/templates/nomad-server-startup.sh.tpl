#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

log() {
	msg=$1
	color="\e[1;36m" # Bold, Cyan
	reset="\e[0m"
	echo -e "$${color}$${msg}$${reset}"
}

tune_io_scheduler() {
	log "-----------------------------------------"
	log "Tuning kernel IO scheduler if needed"
	log "-----------------------------------------"
	if [ -f /sys/block/nvme0n1/queue/scheduler ] && grep -q 'mq-deadline' /sys/block/nvme0n1/queue/scheduler
	then
		echo 'mq-deadline' > /sys/block/nvme0n1/queue/scheduler
		echo 'ACTION=="add|change", KERNEL=="nvme0n1", ATTR{queue/scheduler}="mq-deadline"' > /etc/udev/rules.d/99-circleci-io-scheduler.rules
	update-grub
	fi
}

system_update() {
	log "-----------------------------------------"
	log "Updating system"
	log "-----------------------------------------"
	apt-get update && apt-get -y upgrade
}

install() {
	package=$@
	log "-----------------------------------------"
	log "Installing $${package}"
	log "-----------------------------------------"
	apt-get install -y $${package}
}


install_nomad() {
	log "-----------------------------------------"
	log "Installing Nomad Server"
	log "-----------------------------------------"

	install wget gpg coreutils zip
	wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
	echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
	sudo apt-get update


    if [ -z "$nomad_version" ] || [ "$nomad_version"=="latest" ]; then
		install nomad
	else
		install nomad=${nomad_version}
	fi
}

configure_nomad() {
	
	##########################################################################
	log "-----------------------------------------"
	log "Installing TLS Certificates"
	log "-----------------------------------------"
	
	chmod 0700 /etc/nomad/ssl
	
	cat <<-EOT > /etc/nomad/ssl/cert.pem
	${tls_cert}
	EOT
	
	cat <<-EOT > /etc/nomad/ssl/key.pem
	${tls_key}
	EOT
	
	cat <<-EOT > /etc/nomad/ssl/ca.pem
	${tls_ca}
	EOT
	##########################################################################


	##########################################################################
	log "-----------------------------------------"
	log "Setting nomad configuration"
	log "-----------------------------------------"
	
	mkdir -p /etc/nomad
	
	cat <<-EOT > /etc/nomad/config.hcl
	log_level = "DEBUG"
	name = "$(hostname)"
	data_dir = "/opt/nomad"
	datacenter = "default"
	advertise {
	  http = "$(hostname --ip-address)"  # 4646
	  rpc = "$(hostname --ip-address)"   # 4647
	  serf = "$(hostname --ip-address)"  # 4648
	}
	server {
		enabled = true
		bootstrap_expect = ${min_replicas}
		server_join = {
			retry_join = ["${server_retry_join}"]
			retry_max      = 5
    		retry_interval = "30s"
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

	if [ "${tls_cert}" ]; then
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
	##########################################################################



	log "-----------------------------------------"
	log "Writing nomad systemd unit"
	log "-----------------------------------------"
	cat <<-EOT > /etc/systemd/system/nomad.service
	[Unit]
	Description="nomad server"
	[Service]
	Restart=always
	RestartSec=30
	TimeoutStartSec=1m
	ExecStart=/usr/bin/nomad agent -server -config /etc/nomad/config.hcl
	[Install]
	WantedBy=multi-user.target
	EOT

	log "Nomad config:"
	log "-----------------------------------------"
	cat /etc/nomad/config.hcl
	log "-----------------------------------------"

	log ""
	log "Starting up nomad"
	systemctl enable --now nomad
}


tune_io_scheduler
system_update
install ntp
install jq

install_nomad
configure_nomad
