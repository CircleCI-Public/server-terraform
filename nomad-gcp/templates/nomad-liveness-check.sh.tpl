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

get_instance_name() {
    curl -sf -H "Metadata-Flavor: Google" \
        "http://metadata.google.internal/computeMetadata/v1/instance/name" 2>/dev/null
}

get_local_ip() {
    curl -sf -H "Metadata-Flavor: Google" \
        "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip" 2>/dev/null
}

check_nomad_installed() {
    [ -x /usr/bin/nomad ] && systemctl is-active --quiet nomad
}

mark_unhealthy() {
    log "$1 — marking instance for recreation in MIG"
    if /usr/local/bin/nomad-set-unhealthy.sh "$GCP_INSTANCE_NAME" 2>/dev/null; then
        log "Instance $GCP_INSTANCE_NAME marked for recreation in MIG"
    else
        log "Failed to mark instance for recreation (no service account or not in a MIG)"
    fi
    sleep 600
}

check_container_runtime() {
%{ if use_podman ~}
    [ -x /usr/bin/podman ] && systemctl is-active --quiet podman
%{ else ~}
    [ -x /usr/bin/docker ] && systemctl is-active --quiet docker
%{ endif ~}
}

check_server_reachable() {
    local leader
%{ if external_nomad_server ~}
    leader=$(curl -sf --max-time 10 \
        --cacert /etc/ssl/nomad/ca.pem \
        --cert /etc/ssl/nomad/client.pem \
        --key /etc/ssl/nomad/key.pem \
        "https://localhost:4646/v1/status/leader" 2>/dev/null | tr -d '"') || return 1
%{ else ~}
    leader=$(curl -sf --max-time 10 "http://localhost:4646/v1/status/leader" 2>/dev/null | tr -d '"') || return 1
%{ endif ~}
    if [ -z "$leader" ]; then
        log "No leader elected — cluster may have lost quorum"
        return 2
    fi
    if [ "$leader" != "$LAST_LEADER" ]; then
        log "Nomad server leader: $leader"
        LAST_LEADER=$leader
    fi
    return 0
}

check_cluster_membership() {
    [ -z "$LOCAL_IP" ] && return 0
    local peers
%{ if external_nomad_server ~}
    peers=$(curl -sf --max-time 10 \
        --cacert /etc/ssl/nomad/ca.pem \
        --cert /etc/ssl/nomad/client.pem \
        --key /etc/ssl/nomad/key.pem \
        "https://localhost:4646/v1/status/peers" 2>/dev/null) || return 0
%{ else ~}
    peers=$(curl -sf --max-time 10 "http://localhost:4646/v1/status/peers" 2>/dev/null) || return 0
%{ endif ~}
    if ! echo "$peers" | grep -q "$LOCAL_IP"; then
        log "This server ($LOCAL_IP) is not in the Nomad peer list: $peers"
        return 1
    fi
    return 0
}

GCP_INSTANCE_NAME=$(get_instance_name)
LOCAL_IP=$(get_local_ip)
log "Starting nomad liveness check (interval: $CHECK_INTERVAL s, max failures: $MAX_FAILURES, instance: $GCP_INSTANCE_NAME, local_ip: $LOCAL_IP)"

log "Waiting for installation to complete..."
until [ -x /usr/bin/nomad ] || [ "$SECONDS" -gt 900 ]; do
    sleep 30
done
log "Installation wait complete (elapsed: $${SECONDS}s)"

if [ ! -x /usr/bin/nomad ]; then
    log "Nomad failed to install within 15 minutes"
    mark_unhealthy "Nomad failed to install"
    exit 1
fi

while true; do
    if ! check_nomad_installed; then
        mark_unhealthy "Nomad binary missing or service not active"
        FAILURE_COUNT=0
        RESTART_COUNT=0
        continue
    fi

    if ! check_container_runtime; then
        mark_unhealthy "Container runtime missing or not active"
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
                mark_unhealthy "Nomad failed after $RESTART_COUNT restarts"
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
