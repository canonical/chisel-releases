#!/usr/bin/env bash
# spellchecker: ignore rootfs
source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices squid_core)"

setup_squid
restart_squid

# Assertions
ps -aux | grep -q "unlinkd"
ps -aux | grep -q "logfile-daemon /var/log/squid/access.log"
test_proxy "core"
