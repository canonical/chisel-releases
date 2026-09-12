#!/bin/bash
#spellchecker: ignore rootfs timedatectl timedated nsrun nsystemctl tzdata

# What a consumer gets from systemd_timedate: a daemon that owns the clock
# settings, and a tool that reads and writes them over the bus. The zone data
# is tzdata's, so a timezone this test sets has to come from there.

# shellcheck source=tests/spread/integration/systemd/boot_helpers.sh
. ./boot_helpers.sh

# the slice on its own carries what its own programs need
rootfs="$(install-slices systemd_timedate)"
for bin in /usr/bin/timedatectl /usr/lib/systemd/systemd-timedated; do
  chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "systemd"
done
clean-rootfs "$rootfs"

# with a manager, a bus and zone data under it, the daemon does its job
rootfs="$(install-slices systemd_timedate systemd_core systemd_dbus-services dbus_services tzdata_etc)"

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"

nsystemctl start systemd-timedated.service
nsystemctl is-active systemd-timedated.service
nsrun timedatectl | grep -Fq "Local time:"
nsrun timedatectl show -p TimeUSec | grep -Fq "TimeUSec="

# a timezone the daemon sets is the one it reports back
nsrun timedatectl set-timezone UTC
test "$(nsrun timedatectl show -p Timezone --value)" = "UTC"
nsrun timedatectl set-timezone Etc/UTC
test "$(nsrun timedatectl show -p Timezone --value)" = "Etc/UTC"

# and it only accepts zones tzdata actually ships
! nsrun timedatectl set-timezone Mars/Olympus 2>/dev/null

shutdown_rootfs
