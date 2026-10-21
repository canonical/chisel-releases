#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_echo coreutils_stdbuf)"
chroot "$rootfs" stdbuf --version
test "$(chroot "$rootfs" stdbuf -oL echo "Hello, World!")" = "Hello, World!"
