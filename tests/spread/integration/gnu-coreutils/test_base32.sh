#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnubase32

rootfs="$(install-slices gnu-coreutils_base32)"
chroot "$rootfs" gnubase32 --version
printf "hello" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnubase32 test_file)" = "NBSWY3DP"
echo "NBSWY3DP" > "$rootfs/encoded"
test "$(chroot "$rootfs" gnubase32 -d encoded)" = "hello"
