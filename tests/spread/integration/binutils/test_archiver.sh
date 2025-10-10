#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils archiver

arch=$(uname -m)-linux-gnu

rootfs="$(install-slices \
    binutils-"${arch//_/-}"_archiver \
)"
ln -s "$arch-ar" "$rootfs/usr/bin/ar"

touch "$rootfs/file1" "$rootfs/file2"
chroot "$rootfs" ar rcs archive file1 file2
chroot "$rootfs" ar t archive | grep -q "file1"
chroot "$rootfs" ar t archive | grep -q "file2"
