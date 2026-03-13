#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils

rootfs="$(install-slices debianutils_add-shell)"

grep -q "/bin/sh" "$rootfs/etc/shells" # default shell

chroot "$rootfs" add-shell /foo/bar

# we still have /bin/sh in the list of shells,
# as well as the new shell we just added
grep -q "/bin/sh" "$rootfs/etc/shells"
grep -q "/foo/bar" "$rootfs/etc/shells"
