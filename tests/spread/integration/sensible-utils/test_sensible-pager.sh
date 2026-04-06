#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices sensible-utils_sensible-pager)"

chroot "$rootfs" sensible-pager --help 2>&1

exit 99 # debug stop