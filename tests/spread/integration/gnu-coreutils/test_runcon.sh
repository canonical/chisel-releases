#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuruncon

rootfs="$(install-slices gnu-coreutils_runcon)"
chroot "$rootfs" gnuruncon --version
chroot "$rootfs" gnuruncon -t foo_t /bin/true 2>&1 | \
    grep -q "may be used only on a SELinux kernel"
