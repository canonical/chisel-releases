#!/bin/bash
#spellchecker: ignore rootfs sysusers tmpfiles timespan

rootfs="$(install-slices systemd_standard)"

# some tools refuse to run without /proc
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"' EXIT

bins=(
  /usr/bin/kernel-install
  /usr/bin/systemctl
  /usr/bin/systemd-analyze
  /usr/bin/systemd-escape
  /usr/bin/systemd-mute-console
  /usr/bin/systemd-notify
  /usr/bin/systemd-pty-forward
  /usr/bin/systemd-sysusers
  /usr/bin/systemd-tmpfiles
  /usr/lib/systemd/systemd-executor
)
for bin in "${bins[@]}"; do
  chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "systemd"
done

test "$(chroot "$rootfs" systemd-escape --path /foo/bar)" = "foo-bar"
test "$(chroot "$rootfs" systemd-escape --unescape --path foo-bar)" = "/foo/bar"
chroot "$rootfs" systemd-analyze calendar daily | grep -Fq "*-*-* 00:00:00"
chroot "$rootfs" systemd-analyze timespan 1h30m | grep -Fq "1h 30min"

# the shipped configs are the ones the tools actually read
chroot "$rootfs" systemd-tmpfiles --cat-config | grep -Fq "/usr/lib/tmpfiles.d/20-systemd-varlink.conf"
chroot "$rootfs" systemd-sysusers --cat-config | grep -Fq "/usr/lib/sysusers.d/systemd-journal.conf"

# /etc activation links resolve to what the config slices ship
for link in /etc/profile.d/70-systemd-shell-extra.sh /etc/profile.d/80-systemd-osc-context.sh \
  /etc/ssh/ssh_config.d/20-systemd-ssh-proxy.conf; do
  target="$(readlink "$rootfs$link")"
  test -f "$rootfs$target"
done
test "$(readlink "$rootfs/etc/systemd/system-generators/systemd-gpt-auto-generator")" = "/dev/null"
