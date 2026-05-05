#!/bin/bash
MAX_FAILURES=5
MAX_RESTARTS=5
CHECK_INTERVAL=30
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
        "https://localhost:4646/v1/status/leader" 2>/dev/null | tr -d '"')
%{ else ~}
    leader=$(curl -sf --max-time 10 "http://localhost:4646/v1/status/leader" 2>/dev/null | tr -d '"')
%{ endif ~}
    if [ -n "$leader" ]; then
        if [ "$leader" != "$LAST_LEADER" ]; then
            log "Nomad server leader: $leader"
            LAST_LEADER=$leader
        fi
        return 0
    fi
    return 1
}

GCP_INSTANCE_NAME=$(get_instance_name)
log "Starting nomad liveness check (interval: $CHECK_INTERVAL s, max failures: $MAX_FAILURES, instance: $GCP_INSTANCE_NAME)"

log "Waiting for installation to complete..."
until [ -x /usr/bin/nomad ] || [ "$SECONDS" -gt 900 ]; do
    sleep 30
done
log "Installation wait complete (elapsed: $${SECONDS}s)"

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

    if check_server_reachable; then
        FAILURE_COUNT=0
        RESTART_COUNT=0
    else
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        log "Server unreachable (failure $FAILURE_COUNT/$MAX_FAILURES)"
        if [ "$FAILURE_COUNT" -ge "$MAX_FAILURES" ]; then
            if [ "$RESTART_COUNT" -ge "$MAX_RESTARTS" ]; then
                mark_unhealthy "Nomad failed after $RESTART_COUNT restarts"
                FAILURE_COUNT=0
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
