#!/usr/bin/env bash
# spellchecker: ignore rootfs
source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices squid_core)"

setup_squid "minimal"
restart_squid

# Assertions
ps -aux | grep -q "unlinkd"
ps -aux | grep -q "logfile-daemon"
test_proxy "core"
