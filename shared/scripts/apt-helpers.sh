# shellcheck shell=bash
# Shared apt/dpkg helpers injected into the Nomad startup templates via the
# `apt_helpers` templatefile variable. Kept provider-agnostic (uses `echo`, not
# the GCP-only `log` helper) so a single copy works for AWS and GCP, client and
# server. Edit here only — the startup templates interpolate this verbatim.
prepare_apt() {
    echo "-------------------------------------------"
    echo "     Preparing apt"
    echo "-------------------------------------------"
    # Pause apt-daily so it doesn't hold the dpkg lock during install;
    # resume_apt_timers re-enables it once setup is done.
    systemctl stop apt-daily.timer apt-daily-upgrade.timer apt-daily.service apt-daily-upgrade.service unattended-upgrades 2>/dev/null || true

    # Make apt wait for the lock instead of failing when it's held.
    echo 'DPkg::Lock::Timeout "600";' > /etc/apt/apt.conf.d/99lock-timeout

    # Wait out any apt/dpkg process still holding the lock.
    local -i waited=0
    while fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; do
        if (( waited >= 300 )); then
            echo "apt/dpkg lock still held after 300s — continuing anyway"
            break
        fi
        echo "waiting for apt/dpkg lock..."
        sleep 5
        waited=$((waited + 5))
    done
}

resume_apt_timers() {
    # Restart the daily security-update timers and the unattended-upgrades
    # service that prepare_apt paused, so security updates resume once setup is
    # done. (apt-daily.service / apt-daily-upgrade.service are oneshots fired by
    # the timers, so they don't need an explicit start.)
    echo "Resuming apt-daily timers and unattended-upgrades"
    systemctl start apt-daily.timer apt-daily-upgrade.timer unattended-upgrades 2>/dev/null || true
}
