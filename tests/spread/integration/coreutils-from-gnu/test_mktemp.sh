#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_mktemp)"
chroot "$rootfs" mktemp --version
mkdir -p "$rootfs/tmp"
tmp_file="$(chroot "$rootfs" mktemp /tmp/test.XXXXXX)"
test -f "$rootfs$tmp_file"
tmp_dir="$(chroot "$rootfs" mktemp -d /tmp/test.XXXXXX)"
test -d "$rootfs$tmp_dir"
