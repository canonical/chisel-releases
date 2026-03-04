#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils

rootfs="$(install-slices debianutils_tempfile)"

chroot "$rootfs" tempfile --help | grep -q "Usage: tempfile"
chroot "$rootfs" tempfile --version | grep -q "tempfile"

tempfile=$(chroot "$rootfs" tempfile --prefix=foo --suffix=bar)
echo "$tempfile" | grep -q "foo.*bar"
test -f "$rootfs/$tempfile"

tempfile=$(chroot "$rootfs" tempfile --mode=0777)
test -f "$rootfs/$tempfile"
test "$(stat -c "%a" "$rootfs/$tempfile")" = "777"