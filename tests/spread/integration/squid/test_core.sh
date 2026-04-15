#!/usr/bin/env bash
# spellchecker: ignore rootfs
source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices \
    squid_core \
    base-files_base \
    base-passwd_data \
    libc-bin_nsswitch)"

setup_squid
restart_squid
test_proxy "core"
