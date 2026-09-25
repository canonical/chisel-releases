#!/bin/bash
#spellchecker: ignore rootfs mcookie

rootfs="$(install-slices util-linux_mcookie)"

chroot "$rootfs" mcookie | grep -E '^[0-9a-f]{32}$'
