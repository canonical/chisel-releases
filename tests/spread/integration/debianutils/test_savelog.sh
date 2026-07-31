#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils savelog

rootfs="$(install-slices debianutils_savelog)"

# there is no help so we pass an invalid flag to get the usage message
chroot "$rootfs" savelog --foo 2>&1| grep -q "Usage: savelog"

# savelog with compression. this should fail because we do not include gzip by default
chroot "$rootfs" savelog /var/log/test.log 2>&1 | \
    grep -q "Compression binary not available, please make sure 'gzip' is installed"

# savelog without compression. this should succeed and create the log file
chroot "$rootfs" savelog -l -t /var/log/test.log
test -f "$rootfs/var/log/test.log.0"
test -f "$rootfs/var/log/test.log" # savelog should have touch the original file

# try again but this time install gzip too
rootfs="$(install-slices debianutils_savelog gzip_bins)"
chroot "$rootfs" savelog /var/log/test.log
test -f "$rootfs/var/log/test.log.0"

# try again with xz compression
rootfs="$(install-slices debianutils_savelog xz-utils_bins)"
chroot "$rootfs" savelog -J /var/log/test.log
test -f "$rootfs/var/log/test.log.0"
