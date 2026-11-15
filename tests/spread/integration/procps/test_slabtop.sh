#!/usr/bin/env bash
# spellchecker: ignore rootfs procps slabtop

rootfs="$(install-slices procps_slabtop)"

chroot "$rootfs" slabtop --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" slabtop --version 2>&1 | grep -Fq 'slabtop from procps-ng'
