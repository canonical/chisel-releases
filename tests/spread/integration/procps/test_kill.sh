#!/usr/bin/env bash
# spellchecker: ignore rootfs procps

rootfs="$(install-slices procps_kill)"

chroot "$rootfs" kill --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" kill --version 2>&1 | grep -Fiq 'kill from procps-ng'

# List signals and verify known ones are present
chroot "$rootfs" kill -l | grep -Fq 'HUP'
chroot "$rootfs" kill -l | grep -Fq 'TERM'

# Spawn a process, verify it exists, kill it, verify it's gone
rootfs_2="$(install-slices procps_kill bash_bins)"

mkdir -p "$rootfs_2"/proc
mount --bind /proc "$rootfs_2"/proc
trap "umount '$rootfs_2'/proc" EXIT

chroot "$rootfs_2" bash -c '
    sleep 1000 &
    pid=$!
    kill -0 "$pid"
    kill -9 "$pid"
    wait "$pid" 2>/dev/null || true
    ! kill -0 "$pid" 2>/dev/null
'
