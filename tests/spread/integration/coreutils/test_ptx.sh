#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_ptx)"
chroot "$rootfs" ptx --version
echo "hello world" > "$rootfs/test_file"
chroot "$rootfs" ptx test_file | grep -q "hello   world"
