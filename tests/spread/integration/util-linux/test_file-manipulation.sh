#!/bin/bash
#spellchecker: ignore rootfs hardlink

rootfs="$(install-slices util-linux_file-manipulation)"

mkdir -p "$rootfs"/tmp
chroot "$rootfs" fallocate --length 1M /tmp/fallocate-test
test -f "$rootfs"/tmp/fallocate-test

mkdir -p "$rootfs"/tmp/hardlink-test
echo "Hello world" > "$rootfs"/tmp/hardlink-test/file1
cp "$rootfs"/tmp/hardlink-test/file1 "$rootfs"/tmp/hardlink-test/file2
chroot "$rootfs" hardlink /tmp/hardlink-test/ | grep -iq 'Saved:[[:blank:]]*12 B'

chroot "$rootfs" more /usr/share/doc/util-linux/copyright | grep -iq "format"
