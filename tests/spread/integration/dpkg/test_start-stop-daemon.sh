#!/bin/bash
#spellchecker: ignore rootfs doesnotexist opendir rbind

# Smoke test for the start-stop-daemon utility provided by the
# dpkg_start-stop-daemon slice.

rootfs="$(install-slices dpkg_start-stop-daemon)"

chroot "$rootfs" start-stop-daemon --help 2>&1 | grep -Fiq "usage: start-stop-daemon"

# 'unable to determine status' (because no /proc)
code=0
out=$(chroot "$rootfs" start-stop-daemon --status --name doesnotexist 2>&1) || code=$?
test "$code" -eq 4
grep -Fiq "unable to opendir /proc" <<< "$out"

# mount proc
mkdir -p "$rootfs/proc"
mount --rbind /proc "$rootfs/proc"
trap "umount -l '$rootfs/proc' || true" EXIT

# 'program is not running'
code=0
chroot "$rootfs" start-stop-daemon --status --name doesnotexist 2>&1 || code=$?
test "$code" -eq 3

# 'program is running' — use --pid with PID 1 (init), which must exist.
code=0
chroot "$rootfs" start-stop-daemon --status --pid 1 2>&1 || code=$?
test "$code" -eq 0
