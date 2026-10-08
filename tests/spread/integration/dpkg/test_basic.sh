#!/bin/bash
#spellchecker: ignore rootfs dpkg

. ./helpers.sh

# Test package installation without dependencies or maintainer scripts.
rootfs="$(install-slices dpkg_bins)"
make_fixture "$rootfs"
build_fixture "$rootfs"

chroot "$rootfs" dpkg --install /fixture.deb
test "$(chroot "$rootfs" dpkg-query -W -f="\${Status}" dpkg-fixture)" = 'install ok installed'
cmp "$rootfs/fixture/usr/share/dpkg-fixture/payload" "$rootfs/usr/share/dpkg-fixture/payload"

chroot "$rootfs" dpkg --remove dpkg-fixture
test ! -e "$rootfs/usr/share/dpkg-fixture/payload"
