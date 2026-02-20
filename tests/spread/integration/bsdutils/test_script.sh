#!/usr/bin/env bash
#spellchecker: ignore rootfs bsdutils

rootfs="$(install-slices bsdutils_script)"

chroot "$rootfs" /usr/bin/script --help
chroot "$rootfs" /usr/bin/script --version

exit 99