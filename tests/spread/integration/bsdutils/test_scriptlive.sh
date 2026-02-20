#!/usr/bin/env bash
#spellchecker: ignore rootfs bsdutils scriptlive

rootfs="$(install-slices bsdutils_scriptlive)"

chroot "$rootfs" /usr/bin/scriptlive --help
chroot "$rootfs" /usr/bin/scriptlive --version

exit 99