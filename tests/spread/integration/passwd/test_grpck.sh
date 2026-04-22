#!/bin/bash
#spellchecker: ignore rootfs grpck

rootfs="$(install-slices passwd_grpck)"

# test basic help output
chroot "$rootfs" grpck --help | grep -iq "usage"

# should be fine with empty group file
mkdir -p "$rootfs/etc" && touch "$rootfs/etc/group"
chroot "$rootfs" grpck

echo "foo:x:0:" > "$rootfs/etc/group"
chroot "$rootfs" grpck

echo "foo:x:0:foo" > "$rootfs/etc/group"
chroot "$rootfs" grpck 2>&1 | grep -q "group foo: no user foo"
