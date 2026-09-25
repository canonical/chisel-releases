#!/bin/bash
#spellchecker: ignore rootfs lsns nsenter coreutils NPROCS

rootfs="$(install-slices \
    util-linux_namespace \
    coreutils_sleep \
)"

mkdir "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount $rootfs/proc || true" EXIT

chroot "$rootfs" lsns --raw | grep -iE '^NS\s+TYPE\s+NPROCS\s+PID\s+USER\s+COMMAND$'
chroot "$rootfs" nsenter -t $$ --mount --uts --ipc --net --pid sleep 0.1
chroot "$rootfs" unshare sleep 0.1
