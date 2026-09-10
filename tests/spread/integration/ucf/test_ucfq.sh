#!/bin/bash
#spellchecker: ignore rootfs conffile colons

rootfs="$(install-slices ucf_ucfq)"
mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null"

chroot "$rootfs" ucfq --help 2>&1 | grep -iq "usage: ucfq"

# with no registry there is nothing to report, for files or for packages
test -z "$(chroot "$rootfs" ucfq)"
test -z "$(chroot "$rootfs" ucfq no-such-package)"

# an argument with a slash in it is a path, and paths must be absolute
chroot "$rootfs" ucfq relative/path.conf > /tmp/output 2>&1
grep -q "fully qualified path name" /tmp/output

# columns are package, exists, changed
test "$(chroot "$rootfs" ucfq --with-colons /etc/absent.conf)" = "/etc/absent.conf:::"

mkdir -p "$rootfs/etc"
echo x > "$rootfs/etc/present.conf"
test "$(chroot "$rootfs" ucfq --with-colons /etc/present.conf)" = "/etc/present.conf::Yes:"

# once a hash is on record, ucfq compares it against the file on disk
mkdir -p "$rootfs/var/lib/ucf"
echo "00000000000000000000000000000000  /etc/present.conf" > "$rootfs/var/lib/ucf/hashfile"
test "$(chroot "$rootfs" ucfq --with-colons /etc/present.conf)" = "/etc/present.conf::Yes:Yes"

hash="$(md5sum "$rootfs/etc/present.conf" | awk '{print $1}')"
echo "$hash  /etc/present.conf" > "$rootfs/var/lib/ucf/hashfile"
test "$(chroot "$rootfs" ucfq --with-colons /etc/present.conf)" = "/etc/present.conf::Yes:No"

# the tabular form carries a header, the colon form does not
chroot "$rootfs" ucfq /etc/present.conf > /tmp/output
grep -q "^Configuration file" /tmp/output
chroot "$rootfs" ucfq --with-colons /etc/present.conf > /tmp/output
! grep -q "^Configuration file" /tmp/output
