#!/usr/bin/env bash
# spellchecker: ignore rootfs
source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices squid_standard)"

# Test helper-mux individually (TODO)

# Use log_db_daemon instead of the default log_file_daemon (TODO: required MySQL running in localhost)
# echo "logfile_daemon /usr/lib/squid/log_db_daemon" >> "$rootfs/etc/squid/squid.conf"
# echo "access_log daemon:/localhost/squid_log/access_log/user/pass squid" >> "$rootfs/etc/squid/squid.conf"

setup_squid
restart_squid

# Assertions
ps -aux | grep -q "unlinkd"
ps -aux | grep -q "pinger"
ps -aux | grep -q "diskd"
# ps -aux | grep -q "log_db_daemon"

test_proxy "standard"
