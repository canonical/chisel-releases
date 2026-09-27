#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuptx

rootfs="$(install-slices gnu-coreutils_ptx)"
chroot "$rootfs" gnuptx --version
echo "hello world" > "$rootfs/test_file"
chroot "$rootfs" gnuptx test_file | grep -q "hello   world"
