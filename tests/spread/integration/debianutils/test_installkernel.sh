#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils installkernel

rootfs="$(install-slices debianutils_installkernel)"

chroot "$rootfs" installkernel --help 2>&1 | grep -q "Usage: installkernel"

boot="/foo/bar/boot"
mkdir -p "$rootfs/$boot"
echo "dummy image" > "$rootfs/image"
echo "dummy System.map" > "$rootfs/System.map"

# install
chroot "$rootfs" installkernel 5.10.0-test /image /System.map "$boot"
ls "$rootfs/$boot"
test -f "$rootfs/$boot/vmlinuz-5.10.0-test"
test -f "$rootfs/$boot/System.map-5.10.0-test"

# install the same version. should create .old files
chroot "$rootfs" installkernel 5.10.0-test /image /System.map "$boot"
test -f "$rootfs/$boot/vmlinuz-5.10.0-test.old"
test -f "$rootfs/$boot/System.map-5.10.0-test.old"

# install a new version
chroot "$rootfs" installkernel 5.11.0-test /image /System.map "$boot"
test -f "$rootfs/$boot/vmlinuz-5.11.0-test"
test -f "$rootfs/$boot/System.map-5.11.0-test"
test -f "$rootfs/$boot/vmlinuz-5.10.0-test.old"
test -f "$rootfs/$boot/System.map-5.10.0-test.old"
