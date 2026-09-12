#!/bin/bash
#spellchecker: ignore rootfs localectl localed nsrun nsystemctl xorg

# What a consumer gets from systemd_locale: the daemon that owns the system
# locale and keyboard settings, its client, and the drop-in that keeps it off
# the X11 configuration. The daemon's own sandbox (PrivateDevices=yes and the
# rest of its namespacing) cannot be set up inside an unprivileged container,
# so it exits 226/NAMESPACE here and the checks below stop at what the
# manager can tell us about the unit the slice ships.

# shellcheck source=tests/spread/integration/systemd/boot_helpers.sh
. ./boot_helpers.sh

# the slice on its own carries what its own programs need
rootfs="$(install-slices systemd_locale)"
for bin in /usr/bin/localectl /usr/lib/systemd/systemd-localed; do
  chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "systemd"
done
clean-rootfs "$rootfs"

# with a manager and a bus under it, the manager reads what the slice ships
rootfs="$(install-slices systemd_locale systemd_core systemd_dbus-services dbus_services)"

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"

# the unit loads, and the manager parses it as a bus-activated service
nsystemctl show -p LoadState --value systemd-localed.service | grep -Fxq "loaded"
test "$(nsystemctl show -p BusName --value systemd-localed.service)" = "org.freedesktop.locale1"
test "$(nsystemctl show -p Type --value systemd-localed.service)" = "notify"

# the drop-in the slice ships is read on top of it
nsrun systemctl cat systemd-localed.service | grep -Fq "x11-keyboard.conf"
nsystemctl show -p ReadOnlyPaths systemd-localed.service | grep -Fq "/etc/X11/xorg.conf.d"

# the client is there and talks to the bus rather than to files
nsrun localectl --help | grep -Fq "set-locale"

shutdown_rootfs
