#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_echo coreutils_sleep coreutils_timeout)"
chroot "$rootfs" timeout --version
test "$(chroot "$rootfs" timeout 1 echo "Done")" = "Done"
rc=0
chroot "$rootfs" timeout 0.1 sleep 5 || rc=$?
test "$rc" = "124"
