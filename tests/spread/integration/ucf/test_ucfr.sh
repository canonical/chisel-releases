#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices ucf_ucfr)"

chroot "$rootfs" ucfr --help | grep -iq "usage: ucfr"
