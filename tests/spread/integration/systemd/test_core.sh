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
  chroot "$rootfs" "/usr/bin/$bin" --version | grep -Eq '^systemd [0-9]+ '
done

# the appliers read the fragments the package ships
chroot "$rootfs" systemd-tmpfiles --cat-config | grep -Fq "/usr/lib/tmpfiles.d/systemd.conf"
chroot "$rootfs" systemd-sysusers --cat-config | grep -Fq "/usr/lib/sysusers.d/basic.conf"

# libacl is in this slice for the ACL verbs in tmpfiles.d. A line whose ACL
# cannot be set is logged and tmpfiles still exits 0, so the ACL has to be
# read back, and that read happens out here rather than in the chroot:
# everything that can display an ACL links libacl, and cutting one in would
# supply the library under test.
mkdir -p "$rootfs/etc/tmpfiles.d"
printf 'd /acltest 0755 - - -\na+ /acltest - - - - u:0:rwx\n' \
  > "$rootfs/etc/tmpfiles.d/chisel-acl.conf"
chroot "$rootfs" systemd-tmpfiles --create /etc/tmpfiles.d/chisel-acl.conf
# shellcheck disable=SC2010 # fixed path, and ls is the only tool in reach
# that reports an ACL at all; the mask moves the group bits, so match the plus
ls -ld "$rootfs/acltest" | grep -Eq '^d[rwx-]{9}\+'
umount "$rootfs/proc"
clean-rootfs "$rootfs"

# with a packaged daemon on top, to see the manager underneath it behave
# bash is here only to produce one log line long enough to be compressed;
# coreutils would do too, but it links libacl and libzstd and so would mask
# both of the checks below
rootfs="$(install-slices systemd_core dbus_services bash_bins)"

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
# a short-lived unit can lose its unit field in the journal; its identifier stays
nsrun journalctl --no-pager -b -t systemd-sysusers | grep -Fq "Creating group"

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

# libzstd is in this slice because journald compresses by default, and an
# entry it compressed cannot be read back without the library. A single field
# over the threshold is enough; the journal header then names the algorithm.
cat > "$rootfs/run/systemd/system/probe-bulk.service" <<'EOF'
[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c "printf 'z%%.0s' {1..20000}"
EOF
nsystemctl daemon-reload
nsystemctl start probe-bulk.service
nsrun journalctl --sync
nsrun journalctl --no-pager -b -u probe-bulk.service -o cat | grep -q 'zzzz'
nsrun journalctl --no-pager --header | grep -Fq "COMPRESSED-ZSTD"

shutdown_rootfs
