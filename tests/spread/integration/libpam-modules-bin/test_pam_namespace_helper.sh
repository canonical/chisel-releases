#!/bin/bash
# spellchecker: ignore rootfs

set -eu

rootfs="$(install-slices libpam-modules-bin_scripts)"

# run with default config (all commented out)
chroot "$rootfs" pam_namespace_helper

test ! -e "$rootfs/tmp-inst"
test ! -e "$rootfs/var/tmp/tmp-inst"

# test with a config entry
printf '\n/tmp  /tmp-inst/  level  root,adm\n' >> "$rootfs/etc/security/namespace.conf"
chroot "$rootfs" pam_namespace_helper

test -d "$rootfs/tmp-inst"
test "$(stat -c '%a' "$rootfs/tmp-inst")" = "0"
