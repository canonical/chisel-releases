#!/bin/bash
#spellchecker: ignore rootfs sysinstall repart logind nsrun nsystemctl

# What systemd_sysinstall adds: an installer, and the target an installer
# medium boots into to run it. systemd-repart and bootctl are not sliced yet,
# so here it gets as far as asking for the first of them, before any disk.

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

# the slice on its own carries what its own programs need
rootfs="$(install-slices systemd_sysinstall)"
for bin in /usr/bin/systemd-sysinstall /usr/bin/systemd-creds /usr/lib/systemd/systemd-logind; do
  chroot "$rootfs" "$bin" --version | grep -Eq '^systemd [0-9]+ '
done
chroot "$rootfs" /usr/bin/systemd-sysinstall </dev/null 2>&1 \
  | grep -Fq "Failed to find systemd-repart binary"
clean-rootfs "$rootfs"

# the target pulls the installer in, and its unit runs it
rootfs="$(install-slices systemd_sysinstall systemd_core systemd_dbus-services dbus_services)"

# the unit wants a console, and a failed install would halt the manager
mkdir -p "$rootfs/etc/systemd/system/systemd-sysinstall.service.d"
cat > "$rootfs/etc/systemd/system/systemd-sysinstall.service.d/override.conf" <<'EOF'
[Service]
StandardInput=null
StandardOutput=journal
StandardError=journal
TTYReset=no
FailureAction=none
EOF

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"
# shellcheck disable=SC2119 # nothing in this closure is expected to fail
assert_failed_units

nsystemctl start system-install.target
for _ in $(seq 1 20); do
  state="$(nsystemctl show -p ActiveState --value systemd-sysinstall.service)"
  [ "$state" = "failed" ] && break
  sleep 0.5
done
test "$state" = "failed"
# it ran, rather than failing to exec (203), and logind came up with it
test "$(nsystemctl show -p ExecMainStatus --value systemd-sysinstall.service)" = "1"
nsrun journalctl --no-pager -b -u systemd-sysinstall.service -o cat \
  | grep -Fq "Failed to find systemd-repart binary"
nsystemctl is-active systemd-logind.service

shutdown_rootfs
