#!/bin/bash
#spellchecker: ignore rootfs virt

rootfs="$(install-slices systemd_core)"

# copy over a couple of services for testing
rootfs_services="$(install-slices systemd_system-services)"
to_copy=(
  /usr/lib/systemd/system/getty@.service
  /usr/lib/systemd/system/getty.target
  /usr/lib/systemd/system/ctrl-alt-del.target
  /usr/lib/systemd/system/reboot.target
)
for f in "${to_copy[@]}"; do
  mkdir -p "$rootfs$(dirname "$f")"
  cp "$rootfs_services$f" "$rootfs$f"
done
  
mkdir "${rootfs}"/proc
mount --bind /proc "${rootfs}"/proc
trap "umount $rootfs/proc" EXIT

chroot "$rootfs" systemctl disable getty@tty1.service
! test -f "$rootfs/etc/systemd/system/getty.target.wants/getty@tty1.service"

chroot "$rootfs" systemctl enable getty@tty1.service
test -f "$rootfs/etc/systemd/system/getty.target.wants/getty@tty1.service"

# run preset-all and test for one of the expected symlinks
ls "$rootfs/usr/lib/systemd/system/"
ls "$rootfs/etc/systemd/system/"
chroot "$rootfs" systemctl preset-all
ls "$rootfs/usr/lib/systemd/system/"
ls "$rootfs/etc/systemd/system/"
test -f "$rootfs/etc/systemd/system/ctrl-alt-del.target"

# Run some auxiliary commands to ensure they don't fail
chroot "$rootfs" /usr/lib/systemd/systemd --help 2>&1 | grep -iq "systemd"
