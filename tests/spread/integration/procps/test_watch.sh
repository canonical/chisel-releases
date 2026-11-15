#!/usr/bin/env bash
# spellchecker: ignore rootfs procps

rootfs="$(install-slices procps_watch)"

chroot "$rootfs" watch --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" watch --version 2>&1 | grep -Fq 'watch from procps-ng'
