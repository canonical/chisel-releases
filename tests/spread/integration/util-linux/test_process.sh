#!/bin/bash
#spellchecker: ignore rootfs coreutils choom chrt ionice prio prlimit setpriv
#spellchecker: ignore setsid taskset uclampset

rootfs="$(install-slices \
    util-linux_process \
    coreutils_sleep \
)"

mkdir "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount $rootfs/proc || true" EXIT

chroot "$rootfs" choom -p 1
chroot "$rootfs" chrt -p 1
chroot "$rootfs" ionice -P 1 | grep -q "prio"
chroot "$rootfs" prlimit | grep -q "CPU"
chroot "$rootfs" setpriv sleep 0.1
chroot "$rootfs" setsid sleep 0.1
chroot "$rootfs" taskset -p 1 | grep -q "pid 1's current affinity mask:"
chroot "$rootfs" uclampset -p 1 | grep -q "util_clamp: min: "
