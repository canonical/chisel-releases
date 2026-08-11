#!/bin/bash

# runs from restore:, so it must cope with a prologue or test that died partway
rootfs="$(cat /tmp/frr-rootfs 2>/dev/null)"
[ -n "${rootfs}" ] || exit 0

chroot "${rootfs}" /usr/lib/frr/frrinit.sh stop || true

umount "${rootfs}/dev" || true
umount "${rootfs}/proc" || true

rm -f /tmp/frr-rootfs
