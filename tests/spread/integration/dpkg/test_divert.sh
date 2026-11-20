#!/bin/bash
#spellchecker: ignore rootfs dpkg distrib truename

rootfs="$(install-slices dpkg_divert)"

echo "original" > "$rootfs/usr/bin/foo"

chroot "$rootfs" dpkg-divert --add --rename --divert /usr/bin/foo.distrib /usr/bin/foo
test ! -e "$rootfs/usr/bin/foo"
grep -qx "original" "$rootfs/usr/bin/foo.distrib"
test "$(chroot "$rootfs" dpkg-divert --truename /usr/bin/foo)" = "/usr/bin/foo.distrib"
list="$(chroot "$rootfs" dpkg-divert --list)"
test "$list" = "local diversion of /usr/bin/foo to /usr/bin/foo.distrib"

chroot "$rootfs" dpkg-divert --remove --rename /usr/bin/foo
test ! -e "$rootfs/usr/bin/foo.distrib"
grep -qx "original" "$rootfs/usr/bin/foo"
test -z "$(chroot "$rootfs" dpkg-divert --list)"
