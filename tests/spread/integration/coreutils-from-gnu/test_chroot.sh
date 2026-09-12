#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_chroot coreutils-from-gnu_echo)"
chroot "$rootfs" /usr/sbin/chroot --version
test "$(chroot "$rootfs" /usr/sbin/chroot / echo "Hello, World!")" = "Hello, World!"
