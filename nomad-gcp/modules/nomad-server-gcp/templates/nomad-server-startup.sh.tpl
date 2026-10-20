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

mitigate_cve_2026_31431() {
  echo "install algif_aead /bin/false" > /etc/modprobe.d/disable-algif.conf
  rmmod algif_aead 2>/dev/null || true
}

distrust_compromised_ca_roots() {
	# October 2026 eMudhra incident: the private keys of eight intermediate CAs
	# were compromised. Those intermediates cross-chain, so both the emSign root
	# and the Comodo AAA root must be distrusted. Dropping only one of them
	# leaves a valid path for a forged certificate.
	# Ref: https://emudhra.we-have-a-problem.com/
	log "--------------------------------------"
	log "Distrusting compromised CA roots"
	log "--------------------------------------"
	apt-get install -y --only-upgrade ca-certificates || true

	# Deactivate both roots locally as well, so that a mirror which has not yet
	# shipped the updated ca-certificates cannot leave this host trusting them.
	sed -i \
		-e 's|^mozilla/emSign_ECC_Root_CA_-_G3.crt|!&|' \
		-e 's|^mozilla/Comodo_AAA_Services_root.crt|!&|' \
		/etc/ca-certificates.conf
	update-ca-certificates --fresh

	# Verification below is a hard gate: everything after this point fetches
	# repository signing keys over TLS validated against this bundle. Without
	# openssl or the bundle itself the check cannot prove anything, so treat a
	# missing tool or file as a failure rather than as a pass.
	if ! command -v openssl >/dev/null 2>&1; then
		apt-get install -y openssl || true
	fi
	if ! command -v openssl >/dev/null 2>&1; then
		log "FATAL: openssl is unavailable, cannot verify the CA bundle"
		exit 1
	fi
	if [ ! -s /etc/ssl/certs/ca-certificates.crt ]; then
		log "FATAL: CA bundle is missing after update-ca-certificates"
		exit 1
	fi
	if awk -v cmd='openssl x509 -noout -subject' \
		'/BEGIN/{p=1} p{print | cmd} /END/{close(cmd); p=0}' \
		/etc/ssl/certs/ca-certificates.crt 2>/dev/null \
		| grep -qE 'CN *= *(emSign ECC Root CA - G3|AAA Certificate Services)'; then
		log "FATAL: compromised CA roots are still trusted, refusing to continue"
		exit 1
	fi
	log "Compromised CA roots are not trusted"
}

install() {
	package=$@
	log "-----------------------------------------"
	log "Installing $${package}"
	log "-----------------------------------------"
	apt-get install -y $${package}
}

setup_liveness_check() {
	log "-----------------------------------------"
	log "Setting up Nomad liveness check"
	log "-----------------------------------------"

	echo "${set_unhealthy_script}" | base64 -d > /usr/local/bin/nomad-set-unhealthy.sh
	chmod 0700 /usr/local/bin/nomad-set-unhealthy.sh

	echo "${liveness_check_script}" | base64 -d > /usr/local/bin/nomad-liveness-check.sh
	chmod 0700 /usr/local/bin/nomad-liveness-check.sh

	cat <<-EOT > /etc/systemd/system/nomad-liveness-check.service
	[Unit]
	Description=Nomad server liveness check
	After=network.target
	[Service]
	Type=simple
	Restart=always
	RestartSec=30
	StartLimitIntervalSec=3600
	StartLimitBurst=3
	ExecStart=/usr/local/bin/nomad-liveness-check.sh
	StandardOutput=journal
	StandardError=journal
	[Install]
	WantedBy=multi-user.target
	EOT

	cat <<-EOT > /etc/logrotate.d/nomad-liveness-check
	/var/log/nomad-liveness-check.log {
	    daily
	    rotate 7
	    compress
	    missingok
	    notifempty
	    copytruncate
	}
	EOT

	systemctl daemon-reload
	systemctl enable --now nomad-liveness-check
}


install_nomad() {
	log "-----------------------------------------"
	log "Installing Nomad Server"
	log "-----------------------------------------"

	install wget gpg coreutils zip jq
	wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
	echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
	sudo apt-get update && sudo apt-get install -y nomad=${nomad_version}

	nomad --version || ( echo "Nomad failed to install" && exit 1 )
}

configure_nomad() {

	##########################################################################
	log "-----------------------------------------"
	log "Installing TLS Certificates"
	log "-----------------------------------------"

	mkdir -p /etc/ssl/nomad/
	chmod 0700 /etc/ssl/nomad/

	cat <<-EOT > /etc/ssl/nomad/server.pem
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
	echo 'export NOMAD_CLIENT_CERT=/etc/ssl/nomad/server.pem' >> /etc/environment
	echo 'export NOMAD_CLIENT_KEY=/etc/ssl/nomad/key.pem' >> /etc/environment
	echo "export NOMAD_ADDR=https://localhost:4646" >> /etc/environment

	source /etc/environment
	env | grep "NOMAD_"
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
		cert_file = "/etc/ssl/nomad/server.pem"
		key_file	= "/etc/ssl/nomad/key.pem"
	}
	EOT
	##########################################################################

	log ""


	log "-----------------------------------------"
	log "Writing nomad systemd unit"
	log "-----------------------------------------"
	cat <<-EOT > /etc/systemd/system/nomad.service
	[Unit]
	Description="nomad server"
	[Service]
	Environment="NOMAD_CACERT=/etc/ssl/nomad/ca.pem"
	Environment="NOMAD_CLIENT_CERT=/etc/ssl/nomad/server.pem"
	Environment="NOMAD_CLIENT_KEY=/etc/ssl/nomad/key.pem"
	Environment="NOMAD_ADDR=https://localhost:4646"
	Restart=always
	RestartSec=30
	StartLimitIntervalSec=300
	StartLimitBurst=5
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
mitigate_cve_2026_31431
distrust_compromised_ca_roots
install ntp
install jq

setup_liveness_check
install_nomad || exit 1
configure_nomad
