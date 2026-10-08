#!/bin/bash
#spellchecker: ignore rootfs libdaemon dlog

# Build the test program with the release's own gcc in a separate rootfs, so
# nothing is installed on the test host.
tools="$(install-slices gcc_gcc libc6-dev_libs libdaemon-dev_libs libdaemon-dev_headers)"
cp test.c "$tools/"
chroot "$tools" gcc /test.c -ldaemon -o /test-libdaemon

# Run it against libdaemon0_libs alone. base-files_tmp supplies the /tmp the
# PID file test needs.
rootfs="$(install-slices libdaemon0_libs base-files_tmp)"
cp "$tools/test-libdaemon" "$rootfs/"

# daemon_fork() reopens stdio on /dev/null and daemon_close_all() walks
# /proc/self/fd; a sliced rootfs provides neither.
mkdir -p "$rootfs/dev" "$rootfs/proc"
mount --bind /dev "$rootfs/dev"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"; umount "$rootfs/dev"' EXIT

output="$(chroot "$rootfs" /test-libdaemon)"
grep -Fiq "dlog works" <<<"$output"
