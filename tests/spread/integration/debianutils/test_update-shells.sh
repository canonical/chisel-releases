#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils

rootfs="$(install-slices debianutils_update-shells)"

chroot "$rootfs" update-shells --help 2>&1 | grep -q "usage: /usr/sbin/update-shells"

# update with no new shells in shells.d
# should detect the realpath of /bin/sh and add it to /etc/shells
chroot "$rootfs" update-shells --verbose | grep "adding shell /usr/bin/sh"
grep -q "/bin/sh" "$rootfs/etc/shells"
grep -q "/usr/bin/sh" "$rootfs/etc/shells"

# create a new shell and update again
echo "/foo/bar" > "$rootfs/usr/share/debianutils/shells.d/foo-bar"
chroot "$rootfs" update-shells --verbose | grep "adding shell /foo/bar"
grep -q "/foo/bar" "$rootfs/etc/shells"
