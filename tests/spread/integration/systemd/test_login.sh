#!/bin/bash
#spellchecker: ignore rootfs loginctl logind nsrun nsystemctl

# What a consumer gets from systemd_login: a daemon that tracks seats,
# sessions and users, and hands each user a runtime directory.

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

# the slice on its own carries what its own programs need
rootfs="$(install-slices systemd_login)"
for bin in /usr/bin/loginctl /usr/lib/systemd/systemd-logind; do
  chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "systemd"
done

# helpers that insist on specific arguments still prove they load
chroot "$rootfs" /usr/lib/systemd/systemd-user-runtime-dir 2>&1 | grep -Fiq "takes two arguments"
chroot "$rootfs" /usr/lib/systemd/systemd-user-sessions --version 2>&1 | grep -Fiq "Unknown verb"
clean-rootfs "$rootfs"

# with a manager and a bus under it, the daemon does its job
rootfs="$(install-slices systemd_login systemd_core systemd_dbus-services dbus_services)"

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"

nsystemctl start systemd-logind.service
nsystemctl is-active systemd-logind.service

# the daemon answers its client about the three things it tracks
nsrun loginctl list-sessions | grep -Fq "SESSION"
nsrun loginctl list-users | grep -Fq "UID"
nsrun loginctl list-seats | grep -Fq "SEAT"
nsrun loginctl seat-status seat0 | grep -Fq "seat0"

# and it is what creates a user's runtime directory
nsystemctl start user-runtime-dir@0.service
test "$(stat -c '%a %u' "$rootfs/run/user/0")" = "700 0"
nsystemctl stop user-runtime-dir@0.service
! test -d "$rootfs/run/user/0"

shutdown_rootfs
