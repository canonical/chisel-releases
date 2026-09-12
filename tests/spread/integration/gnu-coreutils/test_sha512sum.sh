#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnusha512sum

rootfs="$(install-slices gnu-coreutils_sha512sum)"
chroot "$rootfs" gnusha512sum --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnusha512sum test_file)" = \
    "9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca72323c3d99ba5c11d7c7acc6e14b8c5da0c4663475c2e5c3adef46f73bcdec043  test_file"
chroot "$rootfs" gnusha512sum test_file > "$rootfs/test_file.sum"
chroot "$rootfs" gnusha512sum -c test_file.sum | grep -q "test_file: OK"
