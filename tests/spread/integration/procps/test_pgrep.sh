#!/usr/bin/env bash
# spellchecker: ignore rootfs procps

rootfs="$(install-slices procps_pgrep)"

mkdir -p "$rootfs"/proc
mount --bind /proc "$rootfs"/proc
trap "umount '$rootfs'/proc" EXIT

chroot "$rootfs" pgrep --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" pgrep --version 2>&1 | grep -Fq 'pgrep from procps-ng'

# search for processes and verify output
chroot "$rootfs" pgrep -c . | grep -q '^[0-9]'

# verify the pkill symlink works
chroot "$rootfs" pkill --help 2>&1 | grep -Fiq 'usage:'
chroot "$rootfs" pkill --version 2>&1 | grep -Fq 'pkill from procps-ng'

# find a named process with pgrep and kill it with pkill
rootfs_2="$(install-slices procps_pgrep bash_bins coreutils_sleep)"

mkdir -p "$rootfs_2"/proc
mount --bind /proc "$rootfs_2"/proc
trap "umount '$rootfs_2'/proc; umount '$rootfs'/proc" EXIT

# -P keeps the match to the children of this shell
chroot "$rootfs_2" bash -ec '
    sleep 1000 &
    pid=$!
    found="$(pgrep -P $$ -x sleep)"
    test "$found" = "$pid"
    pkill -P $$ -x sleep
    wait "$pid" || true
    left="$(pgrep -P $$ -x sleep || true)"
    test -z "$left"
'
