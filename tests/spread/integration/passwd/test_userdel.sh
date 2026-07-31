#!/bin/bash
#spellchecker: ignore rootfs userdel

rootfs="$(install-slices passwd_userdel)"

chroot "$rootfs" userdel --help | grep -iq "usage"

mkdir -p "$rootfs/proc"
mount -o bind /proc "$rootfs/proc"
trap "umount $rootfs/proc || true" EXIT

echo "foo:x:1000:1000::/home/foo:/bin/bash" > "$rootfs/etc/passwd"

chroot "$rootfs" userdel foo
! grep -q foo "$rootfs/etc/passwd"
