#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnusha384sum

rootfs="$(install-slices gnu-coreutils_sha384sum)"
chroot "$rootfs" gnusha384sum --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnusha384sum test_file)" = \
    "59e1748777448c69de6b800d7a33bbfb9ff1b463e44354c3553bcdb9c666fa90125a3c79f90397bdf5f6a13de828684f  test_file"
chroot "$rootfs" gnusha384sum test_file > "$rootfs/test_file.sum"
chroot "$rootfs" gnusha384sum -c test_file.sum | grep -q "test_file: OK"
