#!/usr/bin/env bash
# spellchecker: ignore rootfs procps

rootfs="$(install-slices procps_kill)"

chroot "$rootfs" kill --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" kill --version 2>&1 | grep -Fiq 'kill from procps-ng'
