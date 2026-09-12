#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnumkdir

rootfs="$(install-slices gnu-coreutils_mkdir)"
chroot "$rootfs" gnumkdir --version
chroot "$rootfs" gnumkdir test_dir
test -d "$rootfs/test_dir"
chroot "$rootfs" gnumkdir -p foo/bar/baz
test -d "$rootfs/foo/bar/baz"
