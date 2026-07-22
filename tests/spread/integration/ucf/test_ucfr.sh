#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices ucf_ucfr)"

chroot "$rootfs" ucfr --help 2>&1 | grep -iq "usage: ucfr"
