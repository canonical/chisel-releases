#!/bin/bash
#spellchecker: ignore rootfs nsenter nsrun nsystemctl pkill

# What a consumer gets from systemd_mute-console: a program that silences the
# manager's status output on the console while it runs, and restores it after.

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

rootfs="$(install-slices systemd_mute-console)"
chroot "$rootfs" /usr/bin/systemd-mute-console --version | grep -Eq '^systemd [0-9]+ '
clean-rootfs "$rootfs"

rootfs="$(install-slices systemd_mute-console systemd_minimal)"
trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"

test "$(nsystemctl show -p ShowStatus --value)" = "yes"
# the kernel's console log level belongs to the host; leave it alone
nsrun systemd-mute-console --kernel=no --pid1=yes &
muter=$!
for _ in $(seq 1 20); do
  [ "$(nsystemctl show -p ShowStatus --value)" = "no" ] && break
  sleep 0.5
done
test "$(nsystemctl show -p ShowStatus --value)" = "no"

# nsenter does not pass the signal on, so stop the program itself; its
# process name is cut at 15 characters
pkill -TERM -x systemd-mute-co
wait "$muter"
test "$(nsystemctl show -p ShowStatus --value)" = "yes"

shutdown_rootfs
