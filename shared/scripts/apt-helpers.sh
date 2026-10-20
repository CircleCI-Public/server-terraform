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

# `retry` is defined by the startup templates rather than by this file. Fall
# back to a plain call so these helpers stay self-contained if a template ever
# drops it.
_apt_retry() {
    if command -v retry >/dev/null 2>&1; then
        retry "$@"
    else
        "$@"
    fi
}

# The private keys of eight eMudhra intermediate CAs were compromised. Those
# intermediates cross-chain, so both the emSign root and the Comodo AAA root
# have to be distrusted; dropping only one of them leaves a valid path for a
# forged certificate.
#
# Call this after `apt-get update` and before anything fetches a repository
# signing key over TLS. Those fetches are unpinned and are validated against
# this bundle, so a holder of one of the compromised keys who intercepts them
# could substitute their own signing key and then serve signed packages.
#
# Ref: https://emudhra.we-have-a-problem.com/
distrust_compromised_ca_roots() {
    echo "-------------------------------------------"
    echo "     Distrusting compromised CA roots"
    echo "-------------------------------------------"
    _apt_retry apt-get install -y --only-upgrade ca-certificates || true

    # Deactivate both roots locally as well, so that a mirror which has not yet
    # shipped the updated ca-certificates cannot leave this host trusting them.
    sed -i \
        -e 's|^mozilla/emSign_ECC_Root_CA_-_G3.crt|!&|' \
        -e 's|^mozilla/Comodo_AAA_Services_root.crt|!&|' \
        /etc/ca-certificates.conf
    update-ca-certificates --fresh

    # The verification below is a hard gate. Without openssl, or without the
    # bundle itself, the check cannot prove anything, so treat a missing tool
    # or file as a failure rather than as a pass. A broken openssl or an
    # unparsable bundle is the same problem one step further in: it prints no
    # subject lines at all, which reads exactly like "the roots are gone". So
    # count the subjects that were parsed and require that count to match the
    # certificates in the bundle, and the check fails closed whenever it cannot
    # prove anything.
    if ! command -v openssl >/dev/null 2>&1; then
        _apt_retry apt-get install -y openssl || true
    fi
    if ! command -v openssl >/dev/null 2>&1; then
        echo "FATAL: openssl is unavailable, cannot verify the CA bundle"
        exit 1
    fi
    if [ ! -s /etc/ssl/certs/ca-certificates.crt ]; then
        echo "FATAL: CA bundle is missing after update-ca-certificates"
        exit 1
    fi
    local bundle_certs bundle_subjects parsed_certs
    bundle_certs=$(grep -c 'BEGIN CERTIFICATE' /etc/ssl/certs/ca-certificates.crt)
    bundle_subjects=$(openssl crl2pkcs7 -nocrl -certfile /etc/ssl/certs/ca-certificates.crt 2>/dev/null \
        | openssl pkcs7 -print_certs -noout 2>/dev/null \
        | grep '^subject=')
    parsed_certs=$(printf '%s\n' "$bundle_subjects" | grep -c '^subject=')
    if [ "$parsed_certs" -lt 1 ] || [ "$parsed_certs" -ne "$bundle_certs" ]; then
        echo "FATAL: parsed $parsed_certs of $bundle_certs certificates in the CA bundle, cannot verify it"
        exit 1
    fi
    if printf '%s\n' "$bundle_subjects" \
        | grep -qE 'CN *= *(emSign ECC Root CA - G3|AAA Certificate Services)'; then
        echo "FATAL: compromised CA roots are still trusted, refusing to continue"
        exit 1
    fi
    echo "Compromised CA roots are not trusted ($parsed_certs roots checked)"
}
