#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnunumfmt

rootfs="$(install-slices gnu-coreutils_numfmt)"
chroot "$rootfs" gnunumfmt --version
test "$(chroot "$rootfs" gnunumfmt --to=iec 1024)" = "1.0K"
test "$(chroot "$rootfs" gnunumfmt --from=iec 1K)" = "1024"
