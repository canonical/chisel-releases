#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_sha1sum)"
chroot "$rootfs" sha1sum --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" sha1sum test_file)" = \
    "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d  test_file"
chroot "$rootfs" sha1sum test_file > "$rootfs/test_file.sum"
chroot "$rootfs" sha1sum -c test_file.sum | grep -q "test_file: OK"
