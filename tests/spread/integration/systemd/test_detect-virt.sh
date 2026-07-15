#!/bin/bash
#spellchecker: ignore rootfs virt

rootfs="$(install-slices systemd_detect-virt)"

chroot "$rootfs" systemd-detect-virt --help 2>&1 | grep -Fiq "systemd-detect-virt"
chroot "$rootfs" systemd-detect-virt --version 2>&1 | grep -Fiq "systemd"
chroot "$rootfs" systemd-detect-virt --list 2>&1 | grep -Fiq "none"
