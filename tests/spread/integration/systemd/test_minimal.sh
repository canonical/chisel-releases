#!/bin/bash
#spellchecker: ignore rootfs sysusers tmpfiles nsystemctl

# shellcheck source=tests/spread/integration/systemd/boot_helpers.sh
. ./boot_helpers.sh

rootfs="$(install-slices systemd_minimal)"

# the tools run on their own
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
for bin in /usr/bin/systemctl /usr/bin/systemd-sysusers /usr/bin/systemd-tmpfiles \
  /usr/lib/systemd/systemd /usr/lib/systemd/systemd-executor; do
  chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "systemd"
done
chroot "$rootfs" /usr/lib/systemd/systemd-shutdown 2>&1 | grep -Fiq "not executed by init"
chroot "$rootfs" systemd-tmpfiles --cat-config | grep -Fq "/usr/lib/tmpfiles.d/systemd.conf"
chroot "$rootfs" systemd-sysusers --cat-config | grep -Fq "/usr/lib/sysusers.d/basic.conf"
umount "$rootfs/proc"

# the slice is enough for PID 1 to boot, come up clean, and shut down again
trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"

test -z "$(nsystemctl --failed --no-legend)"
test "$(nsystemctl get-default)" = "graphical.target"
for unit in sysinit.target basic.target multi-user.target sockets.target timers.target \
  systemd-sysusers.service systemd-tmpfiles-setup.service systemd-tmpfiles-setup-dev.service; do
  nsystemctl is-active "$unit"
done

# sysusers and tmpfiles ran against the shipped config
grep -q "^systemd-journal:" "$rootfs/etc/group"
test -d "$rootfs/run/user"

shutdown_rootfs
