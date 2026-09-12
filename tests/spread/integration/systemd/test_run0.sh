#!/bin/bash
#spellchecker: ignore rootfs virt nsrun nsystemctl

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

# the slice on its own carries what its own programs need
rootfs="$(install-slices systemd_run0)"
chroot "$rootfs" /usr/bin/run0 --help 2>&1 | grep -Fiq "run0"
for bin in /usr/bin/run0 /usr/bin/systemd-run; do
  chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "systemd"
done
clean-rootfs "$rootfs"

# both ask the manager over the bus, so a manager, a bus and the manager's
# own bus policy have to be under them
rootfs="$(install-slices systemd_run0 systemd_core systemd_dbus-services dbus_services)"

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"
# shellcheck disable=SC2119 # nothing is expected to fail here
assert_failed_units

test "$(nsrun systemd-run --wait --collect --pipe --quiet systemd-detect-virt --container)" != "none"
test "$(nsrun run0 --no-ask-password systemd-detect-virt --container)" != "none"
test "$(nsrun run0 --no-ask-password --user=root systemd-detect-virt --container)" != "none"

shutdown_rootfs
