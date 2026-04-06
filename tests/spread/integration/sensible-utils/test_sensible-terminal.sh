#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices sensible-utils_sensible-terminal)"

chroot "$rootfs" sensible-terminal --help 2>&1

exit 99 # debug stop