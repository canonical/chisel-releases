#!/bin/bash
#spellchecker: ignore rootfs 

rootfs="$(install-slices util-linux_timer)"

chroot "$rootfs" rtcwake --help | grep -iq "usage"
