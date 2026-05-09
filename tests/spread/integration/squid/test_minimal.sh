#!/usr/bin/env bash
# spellchecker: ignore rootfs
source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices squid_minimal)"

setup_squid "minimal"
restart_squid
test_proxy "minimal"
