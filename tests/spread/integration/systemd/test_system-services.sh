#!/bin/bash
#spellchecker: ignore rootfs nsystemctl sysctl sysusers tmpfiles

# What systemd_system-services adds on top of minimal: the stock system units,
# each with the program it runs, so a boot on them alone fails none of them.

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

rootfs="$(install-slices systemd_system-services systemd_minimal)"

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"

# the container cannot mount kernel file systems; nothing else may fail
assert_failed_units sys-kernel-config.mount sys-kernel-debug.mount

# the units sysinit.target pulls in ran their programs
for unit in systemd-sysctl systemd-random-seed systemd-sysusers systemd-tmpfiles-setup; do
  test "$(nsystemctl show -p Result --value "$unit.service")" = "success"
done

# a password request starts the console agent rather than failing it
nsystemctl start systemd-ask-password-console.service
nsystemctl is-active systemd-ask-password-console.service

shutdown_rootfs
