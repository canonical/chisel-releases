#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_link coreutils_unlink)"
chroot "$rootfs" unlink --version
touch "$rootfs/test_file"
chroot "$rootfs" link test_file test_file_link
test -e "$rootfs/test_file_link"
chroot "$rootfs" unlink test_file_link
test ! -e "$rootfs/test_file_link"
