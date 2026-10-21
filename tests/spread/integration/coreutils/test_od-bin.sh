#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_od-bin)"
chroot "$rootfs" od --version
printf "Hello\nWorld\n" > "$rootfs/test_file"
# NOTE: single bytes, so the expected value does not depend on host endianness
test "$(chroot "$rootfs" od -A n -t x1 test_file | tr -d ' \n')" = "48656c6c6f0a576f726c640a"
