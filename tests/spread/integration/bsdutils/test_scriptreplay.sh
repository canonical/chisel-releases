#!/usr/bin/env bash
#spellchecker: ignore rootfs bsdutils scriptreplay

rootfs="$(install-slices bsdutils_scriptreplay)"

chroot "$rootfs" /usr/bin/scriptreplay --help
chroot "$rootfs" /usr/bin/scriptreplay --version

exit 99