#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices procps_sysctl)"

chroot "$rootfs" sysctl --help 2>&1 | grep -iq 'usage:'
chroot "$rootfs" sysctl --version 2>&1 | grep -q 'sysctl from procps-ng'

# test that sysctl can read and write a variable
mkdir -p "$rootfs"/proc/sys/kernel
touch "$rootfs"/proc/sys/kernel/hostname
chroot "$rootfs" sysctl -w kernel.hostname=test-hostname
chroot "$rootfs" sysctl -n kernel.hostname | grep -q 'test-hostname'
grep -q 'test-hostname' "$rootfs"/proc/sys/kernel/hostname

# dry run
chroot "$rootfs" sysctl --dry-run -w kernel.hostname=dry-run-hostname
chroot "$rootfs" sysctl -n kernel.hostname | grep -q 'test-hostname'

# load from file
echo "kernel.hostname=file-hostname" > "$rootfs"/sysctl.conf
chroot "$rootfs" sysctl -p /sysctl.conf
chroot "$rootfs" sysctl -n kernel.hostname | grep -q 'file-hostname'
