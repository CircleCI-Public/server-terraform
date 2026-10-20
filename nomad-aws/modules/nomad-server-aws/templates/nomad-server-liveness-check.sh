#!/bin/bash
MAX_FAILURES=10
MAX_RESTARTS=5
CHECK_INTERVAL=60
FAILURE_COUNT=0
RESTART_COUNT=0
LAST_LEADER=""

log() {
  echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') [nomad-liveness-check] $*" | tee -a /var/log/nomad-liveness-check.log
}

get_instance_id() {
  local token
  token=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null)
  curl -sf -H "X-aws-ec2-metadata-token: $token" \
    "http://169.254.169.254/latest/meta-data/instance-id" 2>/dev/null
}

get_local_ip() {
  local token
  token=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null)
  curl -sf -H "X-aws-ec2-metadata-token: $token" \
    "http://169.254.169.254/latest/meta-data/local-ipv4" 2>/dev/null
}

check_nomad_installed() {
  [ -x /usr/bin/nomad ] && systemctl is-active --quiet nomad
}

mark_unhealthy() {
  log "$1 — marking instance unhealthy in ASG"
  if /usr/local/bin/nomad-set-unhealthy.sh "$EC2_INSTANCE_ID" 2>/dev/null; then
    log "Instance $EC2_INSTANCE_ID marked unhealthy in ASG"
  else
    log "Failed mark instance unhealthy (no IAM role or not in an ASG)"
  fi
  sleep 600
}

check_server_reachable() {
  local leader
  leader=$(curl -sf --max-time 10 \
    --cacert /etc/ssl/nomad/ca.pem \
    --cert /etc/ssl/nomad/server.pem \
    --key /etc/ssl/nomad/key.pem \
    https://localhost:4646/v1/status/leader 2>/dev/null) || return 1
  if [ -z "$leader" ]; then
    log "No leader elected — cluster may have lost quorum"
    return 2
  fi
  if [ "$leader" != "$LAST_LEADER" ]; then
    LAST_LEADER="$leader"
    log "Leader: $LAST_LEADER"
  fi
  return 0
}

check_cluster_membership() {
  [ -z "$LOCAL_IP" ] && return 0
  local peers
  peers=$(curl -sf --max-time 10 \
    --cacert /etc/ssl/nomad/ca.pem \
    --cert /etc/ssl/nomad/server.pem \
    --key /etc/ssl/nomad/key.pem \
    https://localhost:4646/v1/status/peers 2>/dev/null) || return 0
  if ! echo "$peers" | grep -q "$LOCAL_IP"; then
    log "This server ($LOCAL_IP) is not in the Nomad peer list: $peers"
    return 1
  fi
  return 0
}

EC2_INSTANCE_ID=$(get_instance_id)
LOCAL_IP=$(get_local_ip)
log "Starting liveness check for instance $EC2_INSTANCE_ID ($LOCAL_IP)"

for i in {1..30}; do
  if check_nomad_installed; then
    log "Nomad installed and active"
    break
  fi
  log "Waiting for Nomad to be installed and active... ($i/30)"
  sleep 30
done

if ! check_nomad_installed; then
  log "Nomad failed to install within 15 minutes"
  mark_unhealthy "Nomad failed to install"
  exit 1
fi

while true; do
  if ! check_nomad_installed; then
    log "Nomad not installed or not active"
    mark_unhealthy "Nomad not running"
    FAILURE_COUNT=0
    RESTART_COUNT=0
    continue
  fi

  check_server_reachable
  rc=$?
  if [ "$rc" -eq 0 ]; then
    if ! check_cluster_membership; then
      mark_unhealthy "Server ejected from Nomad cluster"
      FAILURE_COUNT=0
      RESTART_COUNT=0
    else
      FAILURE_COUNT=0
      RESTART_COUNT=0
    fi
  else
    [ "$rc" -eq 2 ] && log "Quorum lost — no leader elected"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    log "Server unreachable (failure $FAILURE_COUNT/$MAX_FAILURES)"
    if [ "$FAILURE_COUNT" -ge "$MAX_FAILURES" ]; then
      if [ "$RESTART_COUNT" -ge "$MAX_RESTARTS" ]; then
        mark_unhealthy "Nomad failed $RESTART_COUNT restarts"
        FAILURE_COUNT=0
        RESTART_COUNT=0
      else
        RESTART_COUNT=$((RESTART_COUNT + 1))
        log "Flushing DNS cache and restarting nomad (attempt $RESTART_COUNT/$MAX_RESTARTS)..."
        resolvectl flush-caches
        systemctl restart nomad
        FAILURE_COUNT=0
        log "Nomad restarted, waiting for stabilization"
        sleep 120
      fi
    fi
  fi
  sleep $CHECK_INTERVAL
done
