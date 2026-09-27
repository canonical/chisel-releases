#!/bin/bash
#spellchecker: ignore rootfs hostnamectl hostnamed nsrun nsystemctl

# What a consumer gets from systemd_hostname: a daemon that owns the system
# hostname, and a tool that reads and writes it over the bus.

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

# the slice on its own carries what its own programs need
rootfs="$(install-slices systemd_hostname)"
for bin in /usr/bin/hostnamectl /usr/lib/systemd/systemd-hostnamed; do
  chroot "$rootfs" "$bin" --version | grep -Eq '^systemd [0-9]+ '
done
clean-rootfs "$rootfs"

# with a manager and a bus under it, the daemon does its job
rootfs="$(install-slices systemd_hostname systemd_core dbus_services)"

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"

# the first call starts the daemon over the bus
nsrun hostnamectl | grep -Fq "hostname:"
nsystemctl is-active systemd-hostnamed.service

# the hostname the daemon sets is the one it reads back, and the one on disk
nsrun hostnamectl hostname chisel-test
test "$(nsrun hostnamectl hostname)" = "chisel-test"
grep -Fxq "chisel-test" "$rootfs/etc/hostname"

# chassis lands in machine-info, and the icon the daemon derives follows it
nsrun hostnamectl chassis container
grep -Fxq "CHASSIS=container" "$rootfs/etc/machine-info"
test "$(nsrun hostnamectl icon-name)" = "computer-container"

shutdown_rootfs
