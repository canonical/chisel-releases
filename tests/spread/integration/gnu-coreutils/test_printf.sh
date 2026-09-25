#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuprintf

rootfs="$(install-slices gnu-coreutils_printf)"
chroot "$rootfs" gnuprintf --version
test "$(chroot "$rootfs" gnuprintf "hello\n")" = "hello"
test "$(chroot "$rootfs" gnuprintf "hello-%s\n" "world")" = "hello-world"
test "$(chroot "$rootfs" gnuprintf "number: %d\n" 42)" = "number: 42"
test "$(chroot "$rootfs" gnuprintf "float: %.2f\n" 3.14159)" = "float: 3.14"
