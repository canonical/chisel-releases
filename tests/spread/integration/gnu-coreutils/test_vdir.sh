#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuvdir

rootfs="$(install-slices gnu-coreutils_vdir)"
chroot "$rootfs" gnuvdir --version
mkdir -p "$rootfs/test_dir"
touch "$rootfs/test_dir/test_file"
chmod 644 "$rootfs/test_dir/test_file"
chroot "$rootfs" gnuvdir test_dir | grep -qE '^-rw-r--r-- .* test_file$'
