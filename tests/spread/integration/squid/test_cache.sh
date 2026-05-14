#!/usr/bin/env bash
# spellchecker: ignorerootfssource "$(dirname "$0")/helpers.sh"
rootfs"$(install-slices \
    squid_cache \
    base-files_base \
    base-passwd_data \
    libc-bin_nsswitch)"

setup_squid

# storeid_file_rewrite TEST
# ------------------------------------------------
reset_squid_conf

# Configure authentication
echo "store_id_program /usr/lib/squid/storeid_file_rewrite /etc/squid/storeid.map" >> "$rootfs/etc/squid/squid.conf"
echo "store_id_access allow all" >> "$rootfs/etc/squid/squid.conf"

# Create Map file
mkdir -p "$rootfs/etc/squid"
printf "^http://example.com/test/.*$\thttp://example.com/storeid/test/\n" > "$rootfs/etc/squid/storeid.map"

# Add logging to grep for it later
echo "logformat storeid_test %ru -> %note" >> "$rootfs/etc/squid/squid.conf"
echo "access_log stdio:/var/log/squid/storeid.log storeid_test" >> "$rootfs/etc/squid/squid.conf"

restart_squid
curl -x "http://localhost:3128" "http://example.com/test/12345"
cat "$rootfs/var/log/squid/storeid.log" | grep "http://example.com/storeid/test"
