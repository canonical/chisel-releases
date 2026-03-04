#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils savelog

rootfs="$(install-slices debianutils_savelog)"

# Usage: savelog [-m mode] [-u user] [-g group] [-t] [-c cycle] [-p]
#              [-j] [-C] [-d] [-l] [-r rolldir] [-n] [-q] file ...
#         -m mode    - chmod log files to mode
#         -u user    - chown log files to user
#         -g group   - chgrp log files to group
#         -c cycle   - save cycle versions of the logfile (default: 7)
#         -r rolldir - use rolldir instead of . to roll files
#         -C         - force cleanup of cycled logfiles
#         -d         - use standard date for rolling
#         -D         - override date format for -d
#         -t         - touch file
#         -l         - don't compress any log files (default: compress)
#         -p         - preserve mode/user/group of original file
#         -j         - use bzip2 instead of gzip
#         -J         - use xz instead of gzip
#         -1 .. -9   - compression strength or memory usage (default: 9, except for xz)
#         -x script  - invoke script with rotated log file in $FILE
#         -n         - do not rotate empty files
#         -q         - suppress rotation message
#         file       - log file names

    #   gzip_bins:

chroot "$rootfs" savelog --foo 2>&1| grep -q "Usage: savelog"

chroot "$rootfs" savelog -l /var/log/test.log 2>&1 || true

# savelog with compression. this should fail because we do not include gzip by default
chroot "$rootfs" savelog /var/log/test.log 2>&1 | \
    grep -q "Compression binary not available, please make sure 'gzip' is installed"

# savelog without compression. this should succeed and create the log file
chroot "$rootfs" savelog -l -t /var/log/test.log
test -f "$rootfs/var/log/test.log.1"
test -f "$rootfs/var/log/test.log" # savelog should have touch the original file

# try again but this time install gzip too
rootfs="$(install-slices debianutils_savelog gzip_bins)"
chroot "$rootfs" savelog /var/log/test.log
test -f "$rootfs/var/log/test.log.0"

# try again with xz compression
rootfs="$(install-slices debianutils_savelog xz-utils_bins)"
chroot "$rootfs" savelog -J /var/log/test.log
test -f "$rootfs/var/log/test.log.0"
