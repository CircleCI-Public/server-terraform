#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

log() {
	msg=$1
	color="\e[1;36m" # Bold, Cyan
	reset="\e[0m"
	# echo -e "$${color}$${msg}$${reset}"
	echo -e "$${msg}"
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

	nomad --version || ( echo "Nomad failed to install" && exit 1 )
}

configure_nomad() {
	
	##########################################################################
	log "-----------------------------------------"
	log "Installing TLS Certificates"
	log "-----------------------------------------"

	mkdir -p /etc/ssl/nomad/
	chmod 0700 /etc/ssl/nomad/
	
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
	echo "      Setting environment variables"
	echo "--------------------------------------"
	echo 'export NOMAD_CACERT=/etc/ssl/nomad/ca.pem' >> /etc/environment
	echo 'export NOMAD_CLIENT_CERT=/etc/ssl/nomad/cert.pem' >> /etc/environment
	echo 'export NOMAD_CLIENT_KEY=/etc/ssl/nomad/key.pem' >> /etc/environment
	echo "export NOMAD_ADDR=https://localhost:4646" >> /etc/environment	
	##########################################################################


	##########################################################################
	log "-----------------------------------------"
	log "Setting nomad configuration"
	log "-----------------------------------------"
	
	mkdir -p /etc/nomad
	
	cat <<-EOT > /etc/nomad/server.hcl
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

	cat <<-EOT >> /etc/nomad/server.hcl
	tls {
		http = true
		rpc  = true
		# This verifies the CN ([role].[region].nomad) in the certificate,
		# not the hostname or DNS name of the of the remote party.
		# https://learn.hashicorp.com/tutorials/nomad/security-enable-tls?in=nomad/transport-security#node-certificates
		verify_server_hostname = false
		ca_file	= "/etc/ssl/nomad/ca.pem"
		cert_file = "/etc/ssl/nomad/cert.pem"
		key_file	= "/etc/ssl/nomad/key.pem"
	}
	EOT
	##########################################################################



	log "-----------------------------------------"
	log "Writing nomad systemd unit"
	log "-----------------------------------------"
	cat <<-EOT > /etc/systemd/system/nomad.service
	[Unit]
	Description="nomad server"
	[Service]
	Environment="NOMAD_CACERT=/etc/ssl/nomad/ca.pem"
	Environment="NOMAD_CLIENT_CERT=/etc/ssl/nomad/client.pem"
	Environment="NOMAD_CLIENT_KEY=/etc/ssl/nomad/key.pem"
	Environment="NOMAD_ADDR=https://localhost:4646"	
	Restart=always
	RestartSec=30
	TimeoutStartSec=1m
	ExecStart=/usr/bin/nomad agent -server -config /etc/nomad/server.hcl
	[Install]
	WantedBy=multi-user.target
	EOT

	log "Nomad config:"
	log "-----------------------------------------"
	cat /etc/nomad/server.hcl
	log "-----------------------------------------"

	log ""
	log "Starting up nomad"
	systemctl enable --now nomad
}


tune_io_scheduler
system_update
install ntp
install jq

install_nomad || exit 1
configure_nomad
