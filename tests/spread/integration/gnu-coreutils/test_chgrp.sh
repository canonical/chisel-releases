#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils gnuchgrp

rootfs="$(install-slices base-passwd_data gnu-coreutils_chgrp)"
chroot "$rootfs" gnuchgrp --version
touch "$rootfs/test_file"
chroot "$rootfs" gnuchgrp nogroup test_file
test "$(stat -c '%G' "$rootfs/test_file")" = "nogroup"
chroot "$rootfs" gnuchgrp non-existent-group test_file 2>&1 | grep -q "invalid group"
