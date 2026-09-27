#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices base-passwd_data coreutils-from-gnu_chgrp)"
chroot "$rootfs" chgrp --version
touch "$rootfs/test_file"
chroot "$rootfs" chgrp nogroup test_file
test "$(stat -c '%G' "$rootfs/test_file")" = "nogroup"
chroot "$rootfs" chgrp non-existent-group test_file 2>&1 | grep -q "invalid group"
