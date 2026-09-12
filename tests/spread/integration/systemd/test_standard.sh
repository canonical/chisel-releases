#!/bin/bash
#spellchecker: ignore rootfs virt nsrun nsystemctl hostnamectl loginctl timedatectl networkctl logind hostnamed timedated networkd

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

# unit links are absolute, so resolve them inside the rootfs rather than on the host
resolves_in_rootfs() {
  local target
  target="$(readlink "$rootfs$1")"
  test -f "$rootfs$target"
}

# the slice on its own: enabling and presetting units is offline work
rootfs="$(install-slices systemd_standard)"
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"

chroot "$rootfs" systemctl disable getty@tty1.service
! test -L "$rootfs/etc/systemd/system/getty.target.wants/getty@tty1.service"

chroot "$rootfs" systemctl enable getty@tty1.service
resolves_in_rootfs /etc/systemd/system/getty.target.wants/getty@tty1.service

# run preset-all and test for one of the expected symlinks
chroot "$rootfs" systemctl preset-all
resolves_in_rootfs /etc/systemd/system/ctrl-alt-del.target

chroot "$rootfs" /usr/lib/systemd/systemd --help 2>&1 | grep -Fiq "systemd"
umount "$rootfs/proc"
clean-rootfs "$rootfs"

# with a bus on top, the whole closure boots: generators, every enabled unit,
# the shipped daemons
rootfs="$(install-slices systemd_standard dbus_services)"

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"

# the container cannot mount kernel file systems; nothing else may fail
assert_failed_units sys-kernel-config.mount sys-kernel-debug.mount
nsystemctl is-active multi-user.target
nsystemctl is-active dbus.service

# the ldconfig unit ran against the cut and left a cache behind
test "$(nsystemctl show -p Result --value ldconfig.service)" = "success"
test -s "$rootfs/etc/ld.so.cache"

# the daemons start and answer their own tools over the bus
for daemon in systemd-logind systemd-hostnamed systemd-timedated systemd-networkd; do
  nsystemctl start "$daemon.service"
  nsystemctl is-active "$daemon.service"
done
nsrun hostnamectl hostname chisel-test
test "$(nsrun hostnamectl hostname)" = "chisel-test"
nsrun loginctl list-seats --no-pager | grep -Fq "SEAT"
nsrun timedatectl --no-pager | grep -Fq "Local time"
nsrun networkctl list --no-pager | grep -Fq "lo "

# run0 elevates through PAM and the manager
test "$(nsrun run0 --no-ask-password systemd-detect-virt --container)" != "none"

shutdown_rootfs
