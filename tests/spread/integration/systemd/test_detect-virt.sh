#!/bin/bash
#spellchecker: ignore rootfs virt

rootfs="$(install-slices systemd_detect-virt)"
chroot "${rootfs}/" systemd-detect-virt --help
chroot "${rootfs}/" systemd-detect-virt --list
