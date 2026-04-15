#!/usr/bin/env bash
# spellchecker: ignore rootfs

setup_squid() {
    # Mount dev into the chroot
    mkdir -p "${rootfs}/dev" "${rootfs}/proc" "${rootfs}/sys"
    mount --rbind /dev "${rootfs}/dev"

    # Get the uid:gid for the proxy user
    proxy_uid_gid=$(grep '^proxy:' "${rootfs}/etc/passwd" | cut -d':' -f3,4)

    # Set permissions for squid directories
    chown -R "$proxy_uid_gid" "${rootfs}/" 2>/dev/null || true

    # Configure cache directories for squid and create swap directories
    echo "cache_dir ufs /var/spool/squid 100 16 256" >> "${rootfs}/etc/squid/squid.conf"
    chroot "${rootfs}/" /usr/sbin/squid-gnutls -Nz

    # Configure pinger (maintainer scripts)
    if command -v setcap > /dev/null; then
        setcap cap_net_raw+ep "${rootfs}/usr/lib/squid/pinger"
    else
        chmod u+s "${rootfs}/usr/lib/squid/pinger"
    fi

    # DNS resolution
    cp /etc/hosts "${rootfs}/etc/hosts"
    cp /etc/resolv.conf "${rootfs}/etc/resolv.conf"
}

reset_squid_conf() {
    # Keep original base config (everything before auth)
    sed -i '/# TEST START/,$d' "${rootfs}/etc/squid/squid.conf"
    echo "# TEST START" >> "${rootfs}/etc/squid/squid.conf"
}

cleanup() {
    # Kill existing squid process
    while ps -aux | grep -q "[s]quid-gnutls"; do
        pkill -f "chroot ${rootfs}/ /usr/sbin/squid-gnutls -N" || true
        pkill -f "/usr/sbin/squid-gnutls -N" || true
    done
}

restart_squid() {
    cleanup

    # Start squid in the background
    chroot "${rootfs}/" /usr/sbin/squid-gnutls -N &
    trap cleanup EXIT

    # Wait for squid to be ready
    until ss -ltn | grep -q ':3128'; do
        sleep 0.1
    done
}

test_proxy() {
    local test_case="$1"
    shift
    local curl_opts="$@"

    echo "Testing: $test_case"
    retries=0
    until curl -s $curl_opts --proxy http://localhost:3128 https://ubuntu.com/ >/dev/null; do
        if [ $retries -ge 5 ]; then
            echo "FAILED: $test_case"
            return 1
        fi
        retries=$((retries + 1))
        sleep 1
    done

    echo "OK: $test_case"
}