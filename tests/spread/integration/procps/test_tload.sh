#!/usr/bin/env bash
# spellchecker: ignore rootfs procps tload

rootfs="$(install-slices procps_tload)"

chroot "$rootfs" tload --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" tload --version 2>&1 | grep -Fq 'tload from procps-ng'
