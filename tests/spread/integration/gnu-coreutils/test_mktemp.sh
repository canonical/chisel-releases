#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnumktemp

rootfs="$(install-slices gnu-coreutils_mktemp)"
chroot "$rootfs" gnumktemp --version
mkdir -p "$rootfs/tmp"
tmp_file="$(chroot "$rootfs" gnumktemp /tmp/test.XXXXXX)"
test -f "$rootfs$tmp_file"
tmp_dir="$(chroot "$rootfs" gnumktemp -d /tmp/test.XXXXXX)"
test -d "$rootfs$tmp_dir"
