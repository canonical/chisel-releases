#!/bin/bash
#spellchecker: ignore rootfs virt

rootfs="$(install-slices systemd_standard)"

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
  
# unit links are absolute, so resolve them inside the rootfs rather than on the host
resolves_in_rootfs() {
  local target
  target="$(readlink "$rootfs$1")"
  test -f "$rootfs$target"
}

mkdir "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
trap "umount $rootfs/proc" EXIT

chroot "$rootfs" systemctl disable getty@tty1.service
! test -L "$rootfs/etc/systemd/system/getty.target.wants/getty@tty1.service"

chroot "$rootfs" systemctl enable getty@tty1.service
resolves_in_rootfs /etc/systemd/system/getty.target.wants/getty@tty1.service

# run preset-all and test for one of the expected symlinks
ls "$rootfs/usr/lib/systemd/system/"
ls "$rootfs/etc/systemd/system/"
chroot "$rootfs" systemctl preset-all
ls "$rootfs/usr/lib/systemd/system/"
ls "$rootfs/etc/systemd/system/"
resolves_in_rootfs /etc/systemd/system/ctrl-alt-del.target

# Run some auxiliary commands to ensure they don't fail
chroot "$rootfs" /usr/lib/systemd/systemd --help 2>&1 | grep -Fiq "systemd"
