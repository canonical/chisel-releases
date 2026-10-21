#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnusha256sum

rootfs="$(install-slices gnu-coreutils_sha256sum)"
chroot "$rootfs" gnusha256sum --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnusha256sum test_file)" = \
    "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824  test_file"
chroot "$rootfs" gnusha256sum test_file > "$rootfs/test_file.sum"
chroot "$rootfs" gnusha256sum -c test_file.sum | grep -q "test_file: OK"
