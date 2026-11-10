#!/bin/bash
#spellchecker: ignore rootfs creds

# What a consumer gets from systemd_creds: credentials sealed to this host,
# which open again only here and only under the name they were sealed for.

rootfs="$(install-slices systemd_creds)"
chroot "$rootfs" /usr/bin/systemd-creds --version | grep -Eq '^systemd [0-9]+ '

mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"' EXIT

# the host key cannot be set up without a machine id
mkdir -p "$rootfs/etc" "$rootfs/var/lib/systemd" "$rootfs/work"
echo "0123456789abcdef0123456789abcdef" > "$rootfs/etc/machine-id"
chroot "$rootfs" systemd-creds setup
test -s "$rootfs/var/lib/systemd/credential.secret"

echo "chisel-secret" | chroot "$rootfs" systemd-creds encrypt --with-key=host --name=chisel-test - - \
  > "$rootfs/work/sealed"
! grep -aFq "chisel-secret" "$rootfs/work/sealed" || exit 1
test "$(chroot "$rootfs" systemd-creds decrypt --name=chisel-test - - < "$rootfs/work/sealed")" = "chisel-secret"
! chroot "$rootfs" systemd-creds decrypt --name=other - - < "$rootfs/work/sealed" 2>/dev/null || exit 1
