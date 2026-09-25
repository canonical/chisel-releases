#!/bin/bash
#spellchecker: ignore rootfs pwck

rootfs="$(install-slices passwd_pwck)"

# test basic help output
chroot "$rootfs" pwck --help | grep -iq "usage"

# should be fine with empty passwd
mkdir -p "$rootfs/etc" && touch "$rootfs/etc/passwd"
chroot "$rootfs" pwck

# should complain about missing home and shell
echo "foo:x:0:0:foo:/foo:/foo/bash" > "$rootfs/etc/passwd"
chroot "$rootfs" pwck > /tmp/pwck_output 2>&1 || true
grep -q "directory '/foo' does not exist" /tmp/pwck_output
grep -q "program '/foo/bash' does not exist" /tmp/pwck_output

# should stop complaining about missing home
mkdir -p "$rootfs/foo"

chroot "$rootfs" pwck > /tmp/pwck_output 2>&1 || true
! grep -q "directory '/foo' does not exist" /tmp/pwck_output
grep -q "program '/foo/bash' does not exist" /tmp/pwck_output

# should stop complaining about missing shell
mkdir -p "$rootfs/foo" && touch "$rootfs/foo/bash" && chmod +x "$rootfs/foo/bash"

chroot "$rootfs" pwck > /tmp/pwck_output 2>&1 || true
cat /tmp/pwck_output
! grep -q "directory '/foo' does not exist" /tmp/pwck_output
! grep -q "program '/foo/bash' does not exist" /tmp/pwck_output
