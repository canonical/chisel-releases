#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_echo coreutils-from-gnu_stdbuf)"
chroot "$rootfs" stdbuf --version
test "$(chroot "$rootfs" stdbuf -oL echo "Hello, World!")" = "Hello, World!"
