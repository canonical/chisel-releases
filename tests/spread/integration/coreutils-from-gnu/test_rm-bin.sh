#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_rm-bin)"
chroot "$rootfs" rm --version
touch "$rootfs/test_file"
chroot "$rootfs" rm test_file
test ! -e "$rootfs/test_file"
mkdir -p "$rootfs/test_dir/sub_dir"
chroot "$rootfs" rm -r test_dir
test ! -e "$rootfs/test_dir"
