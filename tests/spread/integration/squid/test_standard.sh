#!/usr/bin/env bash
# spellchecker: ignore rootfs
source "$(dirname "$0")/helpers.sh"

# perl-base_modules is only needed to compile log_db_daemon below
rootfs="$(install-slices \
    squid_standard \
    perl-base_modules
)"

# Create a test user (username: testuser, password: testpass)
mkdir -p "$rootfs/etc/squid/auth"
printf "testuser:$(openssl passwd -apr1 testpass)\n" > "$rootfs/etc/squid/auth/passwd"

# Configured standard NCSA auth managed by helper-mux
echo "auth_param basic program /usr/lib/squid/helper-mux /usr/lib/squid/basic_ncsa_auth /etc/squid/auth/passwd" >> "$rootfs/etc/squid/squid.conf"
echo "auth_param basic children 20 startup=5 idle=1 concurrency=10" >> "$rootfs/etc/squid/squid.conf"

# Startup squid
setup_squid
restart_squid

# Assertions
ps -aux | grep -qF "unlinkd"
ps -aux | grep -qF "pinger"
ps -aux | grep -qF "diskd"
ps -aux | grep -qF "/usr/lib/squid/helper-mux /usr/lib/squid/basic_ncsa_auth /etc/squid/auth/passwd"

test_proxy "standard"

# log_db_daemon only runs against a mysql server, which the test does not have;
# check that it compiles against the DBI stack in the rootfs
chroot "$rootfs" perl -c /usr/lib/squid/log_db_daemon

cleanup
