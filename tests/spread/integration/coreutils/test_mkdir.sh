#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_mkdir)"
chroot "$rootfs" mkdir --version
chroot "$rootfs" mkdir test_dir
test -d "$rootfs/test_dir"
chroot "$rootfs" mkdir -p foo/bar/baz
test -d "$rootfs/foo/bar/baz"
