#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_vdir)"
chroot "$rootfs" vdir --version
mkdir -p "$rootfs/test_dir"
touch "$rootfs/test_dir/test_file"
chmod 644 "$rootfs/test_dir/test_file"
chroot "$rootfs" vdir test_dir | grep -qE '^-rw-r--r-- .* test_file$'
