#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_arch)"
chroot "$rootfs" arch --version
test "$(chroot "$rootfs" arch)" = "$(uname -m)"
