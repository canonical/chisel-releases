#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices systemd_run0)"

chroot "$rootfs" /usr/bin/run0 --help 2>&1 | grep -Fiq "run0"
chroot "$rootfs" /usr/bin/run0 --version 2>&1 | grep -Fiq "systemd"

# try to run something. this will fail because we don't have systemd running
chroot "$rootfs" /usr/bin/run0 echo hi 2>&1 | grep -Fiq "host is down"
