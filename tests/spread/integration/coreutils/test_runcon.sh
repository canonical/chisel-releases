#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_runcon)"
chroot "$rootfs" runcon --version
chroot "$rootfs" runcon -t foo_t /bin/true 2>&1 | \
    grep -q "may be used only on a SELinux kernel"
