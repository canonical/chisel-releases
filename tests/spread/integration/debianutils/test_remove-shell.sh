#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils

rootfs="$(install-slices debianutils_remove-shell)"

grep -q "/bin/sh" "$rootfs/etc/shells" # default shell

# manually add a shell
echo "/foo/bar" >> "$rootfs/etc/shells"
grep -q "/foo/bar" "$rootfs/etc/shells"

# remove /foo/bar
chroot "$rootfs" remove-shell /foo/bar
grep -q "/bin/sh" "$rootfs/etc/shells"
! grep -q "/foo/bar" "$rootfs/etc/shells"

# remove the default shell
chroot "$rootfs" remove-shell /bin/sh
! grep -q "/bin/sh" "$rootfs/etc/shells"
