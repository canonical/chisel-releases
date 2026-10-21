#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnunproc

rootfs="$(install-slices gnu-coreutils_nproc)"
chroot "$rootfs" gnunproc --version
test "$(chroot "$rootfs" gnunproc)" -ge 1
test "$(chroot "$rootfs" gnunproc --all)" -ge 1
