#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_printf)"
chroot "$rootfs" printf --version
test "$(chroot "$rootfs" printf "hello\n")" = "hello"
test "$(chroot "$rootfs" printf "hello-%s\n" "world")" = "hello-world"
test "$(chroot "$rootfs" printf "number: %d\n" 42)" = "number: 42"
test "$(chroot "$rootfs" printf "float: %.2f\n" 3.14159)" = "float: 3.14"
