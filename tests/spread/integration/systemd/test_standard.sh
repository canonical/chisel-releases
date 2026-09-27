#!/bin/bash
#spellchecker: ignore rootfs virt nsrun nsystemctl hostnamectl loginctl timedatectl networkctl logind hostnamed timedated networkd timespan

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

# unit links are absolute, so resolve them inside the rootfs rather than on the host
resolves_in_rootfs() {
  local target
  target="$(readlink "$rootfs$1")"
  test -f "$rootfs$target"
}

# the slice on its own
rootfs="$(install-slices systemd_standard)"
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"

# every tool the slice itself ships answers --version; the rest come from the
# slices it pulls in, and their own tests cover them
bins="$(chisel info --release "$PROJECT_PATH" systemd_standard | grep -oE '^ +/usr/bin/[^:]+' | tr -d ' ')"
test -n "$bins"
while read -r bin; do
  chroot "$rootfs" "$bin" --version | grep -Eq '^systemd [0-9]+ '
done <<<"$bins"
test "$(chroot "$rootfs" systemd-escape --path /foo/bar)" = "foo-bar"
test "$(chroot "$rootfs" systemd-escape --unescape --path foo-bar)" = "/foo/bar"
chroot "$rootfs" systemd-analyze calendar daily | grep -Fq "*-*-* 00:00:00"
chroot "$rootfs" systemd-analyze timespan 1h30m | grep -Fq "1h 30min"

# enabling and presetting units is offline work
chroot "$rootfs" systemctl disable getty@tty1.service
test ! -L "$rootfs/etc/systemd/system/getty.target.wants/getty@tty1.service"

chroot "$rootfs" systemctl enable getty@tty1.service
resolves_in_rootfs /etc/systemd/system/getty.target.wants/getty@tty1.service

# run preset-all and test for one of the expected symlinks
chroot "$rootfs" systemctl preset-all
resolves_in_rootfs /etc/systemd/system/ctrl-alt-del.target

# and the gpt-auto generator ships masked
test "$(readlink "$rootfs/etc/systemd/system-generators/systemd-gpt-auto-generator")" = "/dev/null"

chroot "$rootfs" /usr/lib/systemd/systemd --help | grep -Fiq "systemd"
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
expected="$(nsrun systemd-detect-virt --container || true)"
test -n "$expected"
test "$(nsrun run0 --no-ask-password systemd-detect-virt --container)" = "$expected"

shutdown_rootfs
