#!/bin/bash
#spellchecker: ignore rootfs sysusers tmpfiles nsystemctl nsrun

# What a consumer can do with systemd_minimal: boot a container, supervise
# programs that carry everything they need, and shut the container down.

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

rootfs="$(install-slices systemd_minimal)"

mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
for bin in /usr/bin/systemctl /usr/lib/systemd/systemd /usr/lib/systemd/systemd-executor; do
  chroot "$rootfs" "$bin" --version | grep -Eq '^systemd [0-9]+ '
done
chroot "$rootfs" /usr/lib/systemd/systemd-shutdown 2>&1 | grep -Fiq "not executed by init"
umount "$rootfs/proc"

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"

# the slice on its own boots clean
# shellcheck disable=SC2119 # nothing in this closure is expected to fail
assert_failed_units
test "$(nsystemctl get-default)" = "graphical.target"
for unit in sysinit.target basic.target multi-user.target sockets.target timers.target; do
  nsystemctl is-active "$unit"
done

# a service that carries its own dependencies runs, and gets the private
# directories the manager makes for it without anything else installed
mkdir -p "$rootfs/run/systemd/system"
cat > "$rootfs/run/systemd/system/probe.service" <<'EOF'
[Service]
Type=oneshot
RemainAfterExit=yes
RuntimeDirectory=probe
StateDirectory=probe
ExecStart=/usr/bin/systemctl is-system-running
EOF
nsystemctl daemon-reload
nsystemctl start probe.service
nsystemctl is-active probe.service
test -d "$rootfs/run/probe"
test -d "$rootfs/var/lib/probe"

# systemctl drives the manager without a bus
nsystemctl stop probe.service
test "$(nsystemctl is-active probe.service)" = "inactive"
nsystemctl list-units --no-legend --type=target | grep -Fq "multi-user.target"

# libseccomp is in this slice because the executor turns SystemCallFilter=
# into a filter. Without it the setting silently stops applying, which looks
# exactly like it working, so the unit below denies the syscall it needs to
# exit and has to die of SIGSYS.
cat > "$rootfs/run/systemd/system/probe-seccomp.service" <<'EOF'
[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl --version
SystemCallFilter=~exit_group
EOF
nsystemctl daemon-reload
if nsystemctl start probe-seccomp.service; then
  echo "a unit that denied its own exit syscall still started: filters are not applied" >&2
  exit 1
fi
# which of the two it reports depends on whether core dumping is on
nsystemctl show -p Result --value probe-seccomp.service | grep -Eq '^(signal|core-dump)$'

# nothing in this slice runs as root at boot to set the system up; the
# sysusers.d and tmpfiles.d appliers are systemd_core's
test ! -e "$rootfs/usr/bin/systemd-sysusers"
test ! -e "$rootfs/usr/bin/systemd-tmpfiles"
test -z "$(nsystemctl list-units --no-legend --all 'systemd-tmpfiles-*')"

shutdown_rootfs
