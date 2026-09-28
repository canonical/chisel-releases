#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices base-passwd_data coreutils_pinky)"
chroot "$rootfs" pinky --version
chroot "$rootfs" pinky | grep -q "^Login"
chroot "$rootfs" pinky -l root | grep -q "Directory: /root"
