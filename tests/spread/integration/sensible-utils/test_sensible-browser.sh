#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices sensible-utils_sensible-browser)"

chroot "$rootfs" sensible-browser --help 2>&1

exit 99 # debug stop