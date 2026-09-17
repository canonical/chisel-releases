#!/bin/bash
#spellchecker: ignore rootfs sysusers tmpfiles timespan

rootfs="$(install-slices systemd_standard)"

# some tools refuse to run without /proc
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"' EXIT

# every tool the slice itself ships answers --version (PID 1 and its helpers
# under /usr/lib are covered by the boot tests)
bins="$(chisel info --release "$PROJECT_PATH" systemd_standard | grep -oE '^ +/usr/bin/[^:]+' | tr -d ' ')"
test -n "$bins"
while read -r bin; do
  chroot "$rootfs" "$bin" --version | grep -Eq '^systemd [0-9]+ '
done <<<"$bins"

test "$(chroot "$rootfs" systemd-escape --path /foo/bar)" = "foo-bar"
test "$(chroot "$rootfs" systemd-escape --unescape --path foo-bar)" = "/foo/bar"
chroot "$rootfs" systemd-analyze calendar daily | grep -Fq "*-*-* 00:00:00"
chroot "$rootfs" systemd-analyze timespan 1h30m | grep -Fq "1h 30min"

# the shipped configs are the ones the tools actually read
chroot "$rootfs" systemd-tmpfiles --cat-config | grep -Fq "/usr/lib/tmpfiles.d/systemd.conf"
chroot "$rootfs" systemd-sysusers --cat-config | grep -Fq "/usr/lib/sysusers.d/systemd-journal.conf"

test "$(readlink "$rootfs/etc/systemd/system-generators/systemd-gpt-auto-generator")" = "/dev/null"
