#!/bin/bash
#spellchecker: ignore rootfs getopt namei whereis

rootfs="$(install-slices util-linux_cli-helpers)"

chroot "$rootfs" getopt Hello world | grep " -- world"

mkdir -p "$rootfs"/bin
ln -s /usr/bin/getopt "$rootfs"/bin/getopt
chroot "$rootfs" namei /bin/getopt | grep -q "l getopt -> /usr/bin/getopt"

chroot "$rootfs" whereis getopt | grep "/usr/bin/getopt"
