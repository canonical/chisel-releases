#!/usr/bin/env bash
# spellchecker: ignore rootfs

setup_squid() {
    mode="${1:-standard}"

    # Mount dev into the chroot
    mkdir -p "$rootfs/dev" "$rootfs/proc" "$rootfs/sys"
    mount --rbind /dev "$rootfs/dev"

    # Get the uid:gid for the proxy user
    proxy_uid_gid=$(grep '^proxy:' "$rootfs/etc/passwd" | cut -d':' -f3,4)

    # Set permissions for squid directories - typically just /var/spool/squid 
    # and /var/log/squid. However when inside the testing env, the entire rootfs
    # is required to be owned by the proxy user to prevent squid from failing.
    chown -R "$proxy_uid_gid" "$rootfs/" 2>/dev/null || true

    if [ "$mode" != "minimal" ]; then

        # Debug login (not a requirement, help debug tests)
        echo "debug_options ALL,1 82,9" >> "$rootfs/etc/squid/squid.conf"

        # Configure cache directories for squid and create swap directories
        if [ "$mode" == "core" ]; then
            echo "cache_dir ufs /var/spool/squid 10 16 256" >> "$rootfs/etc/squid/squid.conf"
        else
            echo "cache_dir diskd /var/spool/squid 100 16 256" >> "$rootfs/etc/squid/squid.conf"
        fi

        chroot "$rootfs/" /usr/sbin/squid-gnutls -Nz

        # Configure pinger (maintainer scripts)
        if [ "$mode" == "standard" ]; then
            if command -v setcap > /dev/null; then
                setcap cap_net_raw+ep "$rootfs/usr/lib/squid/pinger"
            else
                chmod u+s "$rootfs/usr/lib/squid/pinger"
            fi
        fi
    fi

    # DNS resolution
    cp /etc/resolv.conf "$rootfs/etc/resolv.conf"
    cp /etc/hosts "$rootfs/etc/hosts"
}

reset_squid_conf() {
    # Keep original base config (everything before auth)
    sed -i '/# TEST START/,$d' "$rootfs/etc/squid/squid.conf"
    echo "# TEST START" >> "$rootfs/etc/squid/squid.conf"
}

cleanup() {
    # Kill existing squid process
    local retries=0
    while ps -aux | grep -q "[s]quid-gnutls"; do
        [ $retries -ge 5 ] && return 1
        pkill -f "chroot $rootfs/ /usr/sbin/squid-gnutls -N" || true
        pkill -f "/usr/sbin/squid-gnutls -N" || true
        retries=$((retries + 1))
        sleep 0.5
    done

    # Ensure the port is free
    for i in $(seq 1 11); do
        ss -ltn | grep -q ':3128 ' || break
        [ $i -ge 10 ] && echo "port 3128 still in use after cleanup" >&2 && return 1
        sleep 1
    done
    
    if [ "$1" != "restart" ]; then
        umount -l "$rootfs/dev" || true
        timeout 10 bash -c "while mountpoint -q '$rootfs/dev'; do sleep 0.5; done"
    fi
}

restart_squid() {
    cleanup "restart"

    # Start squid in the background
    chroot "$rootfs/" /usr/sbin/squid-gnutls -N &
    trap cleanup EXIT

    # Wait for squid to be ready
    local retries=0
    until ss -ltn | grep -q ':3128'; do
        [ $retries -ge 10 ] && echo "Squid failed to start" >&2 && return 1
        retries=$((retries + 1))
        sleep 1
    done
}

test_proxy() {
    local test_case="$1"
    shift
    local curl_opts=("$@")

    echo "Testing: $test_case"
    local retries=0
    until curl -s "${curl_opts[@]}" --proxy http://localhost:3128 https://ubuntu.com/ >/dev/null; do
        if [ $retries -ge 5 ]; then
            echo "FAILED: $test_case"
            return 1
        fi
        retries=$((retries + 1))
        sleep 1
    done

    echo "OK: $test_case"
}

test_proxy_deny() {
    local test_case="$1"
    shift
    local curl_opts=("$@")

    echo "Testing deny: $test_case"
    if curl -fsS --max-time 5 "${curl_opts[@]}" --proxy http://localhost:3128 https://ubuntu.com/ >/dev/null 2>&1; then
        echo "FAILED (request succeeded, expected deny): $test_case"
        return 1
    fi
    echo "OK (denied): $test_case"
}
