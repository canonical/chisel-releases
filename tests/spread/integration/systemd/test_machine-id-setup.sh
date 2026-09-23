#!/bin/bash
#spellchecker: ignore rootfs

# What a consumer gets from systemd_machine-id-setup: an image root gets its
# machine id before it ever boots, and keeps it on later runs.

rootfs="$(install-slices systemd_machine-id-setup)"
chroot "$rootfs" /usr/bin/systemd-machine-id-setup --version | grep -Eq '^systemd [0-9]+ '
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"' EXIT

img="$rootfs/work/img"
mkdir -p "$img/etc"
chroot "$rootfs" systemd-machine-id-setup --root=/work/img
id="$(cat "$img/etc/machine-id")"
grep -Eq '^[0-9a-f]{32}$' <<<"$id"
test "$(chroot "$rootfs" systemd-machine-id-setup --root=/work/img --print)" = "$id"

chroot "$rootfs" systemd-machine-id-setup --root=/work/img
test "$(cat "$img/etc/machine-id")" = "$id"
