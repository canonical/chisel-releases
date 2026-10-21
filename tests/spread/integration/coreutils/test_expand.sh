#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_expand)"
chroot "$rootfs" expand --version
printf "a\tb\n" > "$rootfs/test_file"
test "$(chroot "$rootfs" expand -t 4 test_file)" = "a   b"
