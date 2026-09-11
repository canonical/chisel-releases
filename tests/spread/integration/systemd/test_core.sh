#!/bin/bash
#spellchecker: ignore rootfs journalctl nsrun nsystemctl virt

# shellcheck source=tests/spread/integration/systemd/boot_helpers.sh
. ./boot_helpers.sh

rootfs="$(install-slices systemd_core)"

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"

test -z "$(nsystemctl --failed --no-legend)"
for unit in systemd-journald.service systemd-journald.socket systemd-journald-dev-log.socket; do
  nsystemctl is-active "$unit"
done

# the journal has the boot in it
nsrun journalctl --no-pager -b | grep -Fq "Journal started"
nsrun journalctl --no-pager -b -u systemd-sysusers.service | grep -Fq "Creating group"

# a service shaped like the ones a supervisor generates: ordered against the
# passive targets, logging to the journal, run under the container detection
cat > "$rootfs/run/systemd/system/probe.service" <<'EOF'
[Unit]
Wants=network.target
After=network.target time-set.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemd-detect-virt --container
EOF
nsystemctl daemon-reload
nsystemctl start probe.service
nsystemctl is-active network.target
test "$(nsrun journalctl --no-pager -b -u probe.service -o cat)" != "none"
test "$(nsrun systemd-detect-virt --container)" != "none"

# what a bus daemon would load for the org.freedesktop.systemd1 API
test -f "$rootfs/usr/share/dbus-1/system.d/org.freedesktop.systemd1.conf"
test -f "$rootfs/usr/share/dbus-1/system-services/org.freedesktop.systemd1.service"

shutdown_rootfs
