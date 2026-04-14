#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices squid_core base-files_base base-passwd_data libc-bin_nsswitch)"

# Mount dev into the chroot
mkdir -p "${rootfs}/dev"
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
cp /etc/resolv.conf "${rootfs}/etc/resolv.conf"

# Start squid in the background
setsid chroot "${rootfs}/" /usr/sbin/squid-gnutls -N &
squid_pid=$!
trap 'kill -- -"$squid_pid" 2>/dev/null || true' EXIT

# Test that squid is running and responding to requests
retries=0
until curl -s --proxy http://localhost:3128 https://ubuntu.com/ >/dev/null; do
    if [ $retries -ge 10 ]; then
        echo "Squid did not respond after 10 attempts."
        exit 1
    fi
    retries=$((retries + 1))
    sleep 1
done
