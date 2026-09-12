#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnucut

rootfs="$(install-slices gnu-coreutils_cut)"
chroot "$rootfs" gnucut --version
echo "foo,bar" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnucut -d ',' -f 1 test_file)" = "foo"
test "$(chroot "$rootfs" gnucut -c 5- test_file)" = "bar"
