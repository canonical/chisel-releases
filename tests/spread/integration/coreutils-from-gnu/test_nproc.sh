#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_nproc)"
chroot "$rootfs" nproc --version
test "$(chroot "$rootfs" nproc)" -ge 1
test "$(chroot "$rootfs" nproc --all)" -ge 1
