#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs coreutils pidfile

rootfs="$(install-slices dpkg_start-stop-daemon)"

help=$(chroot "$rootfs" start-stop-daemon --help | head -n 1 || true)
echo "$help" | grep -q "Usage: start-stop-daemon"
version=$(chroot "$rootfs" start-stop-daemon --version | head -n1 || true)
echo "$version" | grep -q "start-stop-daemon"

rootfs_sleep="$(install-slices \
    coreutils_delaying \
    dpkg_start-stop-daemon \
)"

# start-stop-daemon needs /dev/null to start processes in the background
mkdir -p "$rootfs_sleep/dev"
touch "$rootfs_sleep/dev/null"
chmod +x "$rootfs_sleep/dev/null"

# Test that start-stop-daemon can start a simple command in the background
mkdir -p "$rootfs_sleep/var/run"
chroot "$rootfs_sleep" start-stop-daemon \
    --background \
    --start --make-pidfile \
    --pidfile /var/run/sleep.pid \
    --exec /usr/bin/sleep -- 10

# Verify that the process is running
chroot "$rootfs_sleep" start-stop-daemon --status --pidfile /var/run/sleep.pid

# Stop the process
chroot "$rootfs_sleep" start-stop-daemon --stop --pidfile /var/run/sleep.pid

# Verify that the process is no longer running
! chroot "$rootfs_sleep" start-stop-daemon --status --pidfile /var/run/sleep.pid
