#!/bin/bash
#spellchecker: ignore rootfs journalctl nsrun nsystemctl messagebus

# What systemd_core adds: an unmodified unit file from another package
# behaves the way it does on an ordinary Ubuntu system. dbus is the specimen,
# since it declares its user in a sysusers.d fragment, its state directory in
# a tmpfiles.d one, reports readiness over sd_notify and logs to the journal.

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

# the slice on its own carries what its own programs need
rootfs="$(install-slices systemd_core)"
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
for bin in systemd-notify systemd-sysusers systemd-tmpfiles; do
  chroot "$rootfs" "/usr/bin/$bin" --version 2>&1 | grep -Fiq "systemd"
done

# the appliers read the fragments the package ships
chroot "$rootfs" systemd-tmpfiles --cat-config | grep -Fq "/usr/lib/tmpfiles.d/systemd.conf"
chroot "$rootfs" systemd-sysusers --cat-config | grep -Fq "/usr/lib/sysusers.d/basic.conf"
umount "$rootfs/proc"
clean-rootfs "$rootfs"

# with a packaged daemon on top, to see the manager underneath it behave
rootfs="$(install-slices systemd_core dbus_services)"

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"
# shellcheck disable=SC2119 # nothing in this closure is expected to fail
assert_failed_units

# a packaged daemon comes up: its user exists only because the sysusers.d
# fragment it ships was applied, so a manager that skipped that kills it with
# 217/USER, and its state directory comes from the tmpfiles.d fragment
grep -q "^messagebus:" "$rootfs/etc/passwd"
nsystemctl is-active dbus.service
nsystemctl is-active dbus.socket

# the same two appliers set up what systemd's own fragments declare
nsystemctl is-active systemd-sysusers.service
nsystemctl is-active systemd-tmpfiles-setup.service
grep -q "^systemd-journal:" "$rootfs/etc/group"
test -d "$rootfs/run/user"

# the journal is running and holds what the boot-time units printed
for unit in systemd-journald.service systemd-journald.socket systemd-journald-dev-log.socket; do
  nsystemctl is-active "$unit"
done
nsrun journalctl --no-pager -b | grep -Fq "Journal started"
nsrun journalctl --no-pager -b -u systemd-sysusers.service | grep -Fq "Creating group"

# a unit that reports readiness from a script rather than a compiled binary,
# ordered against the targets other packages name
cat > "$rootfs/run/systemd/system/probe.service" <<'EOF'
[Unit]
Wants=network.target
After=network.target time-set.target

[Service]
Type=notify
RemainAfterExit=yes
ExecStart=/usr/bin/systemd-notify --ready --status=chisel-test
StandardOutput=journal
EOF
nsystemctl daemon-reload
nsystemctl start probe.service
nsystemctl is-active probe.service
nsystemctl is-active network.target
test "$(nsystemctl show -p StatusText --value probe.service)" = "chisel-test"

# and what a service prints reaches the journal, which is where StandardOutput
# points unless a unit says otherwise
cat > "$rootfs/run/systemd/system/probe-log.service" <<'EOF'
[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl --version
EOF
nsystemctl daemon-reload
nsystemctl start probe-log.service
nsrun journalctl --no-pager -b -u probe-log.service -o cat | grep -Fiq "systemd"

shutdown_rootfs
