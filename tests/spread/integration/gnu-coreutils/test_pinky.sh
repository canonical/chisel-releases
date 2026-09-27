#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnupinky

rootfs="$(install-slices base-passwd_data gnu-coreutils_pinky)"
chroot "$rootfs" gnupinky --version
chroot "$rootfs" gnupinky | grep -q "^Login"
chroot "$rootfs" gnupinky -l root | grep -q "Directory: /root"
