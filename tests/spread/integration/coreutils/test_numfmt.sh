#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_numfmt)"
chroot "$rootfs" numfmt --version
test "$(chroot "$rootfs" numfmt --to=iec 1024)" = "1.0K"
test "$(chroot "$rootfs" numfmt --from=iec 1K)" = "1024"
