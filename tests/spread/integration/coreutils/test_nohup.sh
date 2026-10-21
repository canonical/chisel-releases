#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_echo coreutils_nohup)"
chroot "$rootfs" nohup --version
test "$(chroot "$rootfs" nohup echo "Hello, World!")" = "Hello, World!"
