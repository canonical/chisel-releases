#!/usr/bin/env bash
#spellchecker: ignore rootfs bsdutils

rootfs="$(install-slices bsdutils_wall)"

chroot "$rootfs" /usr/bin/wall --help
chroot "$rootfs" /usr/bin/wall --version

exit 99