#!/bin/bash
#spellchecker: ignore rootfs networkctl networkd nsrun nsystemctl

# What a consumer gets from systemd_network: a daemon that reads .network
# files and manages links, and a tool that reports on them.

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

# the slice on its own carries what its own programs need
rootfs="$(install-slices systemd_network)"
for bin in /usr/bin/networkctl /usr/lib/systemd/systemd-networkd \
  /usr/lib/systemd/systemd-networkd-wait-online /usr/lib/systemd/systemd-network-generator; do
  chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "systemd"
done
clean-rootfs "$rootfs"

# with a manager and a bus under it, the daemon does its job
rootfs="$(install-slices systemd_network systemd_core systemd_dbus-services dbus_services)"

# the daemon picks its configuration up from the directory the slice makes
test -d "$rootfs/etc/systemd/network"
cat > "$rootfs/etc/systemd/network/10-loopback.network" <<'EOF'
[Match]
Name=lo

[Network]
Address=127.0.0.1/8
EOF

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"

nsystemctl start systemd-networkd.service
nsystemctl is-active systemd-networkd.service

# it enumerates the links it manages, and reports on one of them
nsrun networkctl list | grep -Eq "^ *1 +lo +loopback"
nsrun networkctl status lo | grep -Fq "lo"
nsrun networkctl --json=short list | grep -Fq '"Name":"lo"'

# and the file this test wrote is the configuration it read
nsrun networkctl cat 10-loopback.network | grep -Fq "Address=127.0.0.1/8"

shutdown_rootfs
