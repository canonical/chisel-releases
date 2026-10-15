#!/usr/bin/env bash
# spellchecker: ignore rootfs procps

rootfs="$(install-slices procps_skill)"

chroot "$rootfs" skill --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" skill --version 2>&1 | grep -Fq 'skill from procps-ng'

# list signals in a table and check known ones are present
chroot "$rootfs" skill -L 2>&1 | grep -Fq 'TERM'

# verify the snice symlink works
chroot "$rootfs" snice --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" snice --version 2>&1 | grep -Fq 'snice from procps-ng'
