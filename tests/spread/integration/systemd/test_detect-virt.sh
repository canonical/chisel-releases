#!/bin/bash
#spellchecker: ignore rootfs virt

rootfs="$(install-slices systemd_detect-virt)"

chroot "$rootfs" systemd-detect-virt --help | grep -Fiq "systemd-detect-virt"
chroot "$rootfs" systemd-detect-virt --version | grep -Eq '^systemd [0-9]+ '
chroot "$rootfs" systemd-detect-virt --list | grep -Fiq "none"
