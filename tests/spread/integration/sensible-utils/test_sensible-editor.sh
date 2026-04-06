#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices sensible-utils_sensible-editor)"

chroot "$rootfs" sensible-editor --help 2>&1

exit 99 # debug stop