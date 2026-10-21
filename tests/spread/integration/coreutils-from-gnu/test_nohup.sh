#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_echo coreutils-from-gnu_nohup)"
chroot "$rootfs" nohup --version
test "$(chroot "$rootfs" nohup echo "Hello, World!")" = "Hello, World!"
