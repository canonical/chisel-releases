#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnumd5sum

rootfs="$(install-slices gnu-coreutils_md5sum)"
chroot "$rootfs" gnumd5sum --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnumd5sum test_file)" = \
    "5d41402abc4b2a76b9719d911017c592  test_file"
chroot "$rootfs" gnumd5sum test_file > "$rootfs/test_file.sum"
chroot "$rootfs" gnumd5sum -c test_file.sum | grep -q "test_file: OK"
