#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils-from-gnu_sha224sum)"
chroot "$rootfs" sha224sum --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" sha224sum test_file)" = \
    "ea09ae9cc6768c50fcee903ed054556e5bfc8347907f12598aa24193  test_file"
chroot "$rootfs" sha224sum test_file > "$rootfs/test_file.sum"
chroot "$rootfs" sha224sum -c test_file.sum | grep -q "test_file: OK"
