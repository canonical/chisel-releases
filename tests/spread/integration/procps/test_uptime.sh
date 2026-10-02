#!/usr/bin/env bash
# spellchecker: ignore rootfs procps

rootfs="$(install-slices procps_uptime)"

chroot "$rootfs" uptime --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" uptime --version 2>&1 | grep -Fq 'uptime from procps-ng'
chroot "$rootfs" uptime 2>&1 | grep -Fq 'up'
