#!/bin/bash
# spellchecker: ignore rootfs chkpwd chkexpiry

set -eu

rootfs="$(install-slices libpam-modules-bin_unix-chkpwd)"

# an account database with one current and one expired account
mkdir -p "$rootfs/etc"
printf 'root:x:0:0:root:/root:/bin/sh\nexpired:x:1000:1000::/nonexistent:/bin/sh\n' > "$rootfs/etc/passwd"
printf 'root:*:20000:0:99999:7:::\nexpired:*:1:0:99999:7::2:\n' > "$rootfs/etc/shadow"
chmod 640 "$rootfs/etc/shadow"

# pam_unix runs it without a terminal, naming the user and the check to make
chroot "$rootfs" /usr/sbin/unix_chkpwd root chkexpiry < /dev/null
! chroot "$rootfs" /usr/sbin/unix_chkpwd expired chkexpiry < /dev/null
