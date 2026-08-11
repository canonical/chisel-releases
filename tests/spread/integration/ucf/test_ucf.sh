#!/bin/bash
#spellchecker: ignore rootfs conffile confold confnew confmiss mdsum

rootfs="$(install-slices ucf_ucf)"
mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null"

chroot "$rootfs" ucf --help 2>&1 | grep -iq "usage: ucf"

# argument errors, all raised before any state is touched
rc=0; chroot "$rootfs" ucf > /tmp/output 2>&1 || rc=$?
test "$rc" -eq 2
grep -q "Need exactly two file arguments, got 0" /tmp/output

rc=0; chroot "$rootfs" ucf --purge > /tmp/output 2>&1 || rc=$?
test "$rc" -eq 2
grep -q "Need exactly one file argument when purging, got 0" /tmp/output

rc=0; chroot "$rootfs" ucf /nonexistent /etc/foo.conf > /tmp/output 2>&1 || rc=$?
test "$rc" -eq 1
grep -q "The new file /nonexistent does not exist" /tmp/output

# --dest-dir is accepted by getopt(1) but has no handler behind it
rc=0; chroot "$rootfs" ucf --dest-dir /tmp a b > /tmp/output 2>&1 || rc=$?
test "$rc" -eq 1
grep -q "Internal error" /tmp/output

mkdir -p "$rootfs/usr/share/foo"
echo "v1" > "$rootfs/usr/share/foo/foo.conf"

# first run creates the destination and records its hash
chroot "$rootfs" ucf /usr/share/foo/foo.conf /etc/foo.conf > /tmp/output 2>&1
grep -q "Creating config file /etc/foo.conf with new version" /tmp/output
test "$(cat "$rootfs/etc/foo.conf")" = "v1"
grep -q "/etc/foo.conf" "$rootfs/var/lib/ucf/hashfile"

# re-running against the same shipped version does nothing
chroot "$rootfs" ucf -v /usr/share/foo/foo.conf /etc/foo.conf > /tmp/output 2>&1
grep -q "md5sums match, nothing needs be done" /tmp/output

# a local edit survives as long as the shipped version has not moved
echo "local edit" > "$rootfs/etc/foo.conf"
chroot "$rootfs" ucf /usr/share/foo/foo.conf /etc/foo.conf
test "$(cat "$rootfs/etc/foo.conf")" = "local edit"

chroot "$rootfs" ucf -d1 /usr/share/foo/foo.conf /etc/foo.conf > /tmp/output 2>&1
grep -q "The new start file is" /tmp/output

# a local edit plus an upstream change is a genuine conflict, and resolving it
# needs a debconf frontend, which a chiselled rootfs has no way to provide
echo "v2" > "$rootfs/usr/share/foo/foo.conf"
rc=0; chroot "$rootfs" ucf /usr/share/foo/foo.conf /etc/foo.conf > /tmp/output 2>&1 || rc=$?
test "$rc" -eq 2
grep -q "Need debconf to interact" /tmp/output
test "$(cat "$rootfs/etc/foo.conf")" = "local edit"

rc=0
UCF_FORCE_CONFFOLD=1 UCF_FORCE_CONFFNEW=1 \
    chroot "$rootfs" ucf /usr/share/foo/foo.conf /etc/foo.conf > /tmp/output 2>&1 || rc=$?
test "$rc" -eq 1
grep -q "Only one of UCF_FORCE_CONFFOLD and UCF_FORCE_CONFFNEW" /tmp/output

# confold keeps the edit and parks the shipped version alongside it
DPKG_FORCE=confold chroot "$rootfs" ucf /usr/share/foo/foo.conf /etc/foo.conf
test "$(cat "$rootfs/etc/foo.conf")" = "local edit"
test "$(cat "$rootfs/etc/foo.conf.ucf-dist")" = "v2"

# confnew discards it
echo "v3" > "$rootfs/usr/share/foo/foo.conf"
UCF_FORCE_CONFFNEW=1 chroot "$rootfs" ucf /usr/share/foo/foo.conf /etc/foo.conf \
    > /tmp/output 2>&1
grep -q "Replacing config file /etc/foo.conf with new version" /tmp/output
test "$(cat "$rootfs/etc/foo.conf")" = "v3"

# a destination the user deleted stays deleted unless asked otherwise
rm "$rootfs/etc/foo.conf"
chroot "$rootfs" ucf /usr/share/foo/foo.conf /etc/foo.conf > /tmp/output 2>&1
grep -q "Not replacing deleted config file /etc/foo.conf" /tmp/output
! test -e "$rootfs/etc/foo.conf"

UCF_FORCE_CONFFMISS=1 chroot "$rootfs" ucf /usr/share/foo/foo.conf /etc/foo.conf \
    > /tmp/output 2>&1
grep -q "Recreating deleted config file /etc/foo.conf" /tmp/output
test "$(cat "$rootfs/etc/foo.conf")" = "v3"

# purging drops the hash and the cached copy but never the file itself
cached="$rootfs/var/lib/ucf/cache/:etc:foo.conf"
test -f "$cached"
chroot "$rootfs" ucf --purge /etc/foo.conf
! grep -q "/etc/foo.conf" "$rootfs/var/lib/ucf/hashfile"
! test -e "$cached"
test "$(cat "$rootfs/etc/foo.conf")" = "v3"
# every write rotates the previous generation out of the way
grep -q "/etc/foo.conf" "$rootfs/var/lib/ucf/hashfile.0"

# a file that predates ucf tracking can be adopted from a historical md5sum
destsum="$(md5sum "$rootfs/etc/foo.conf" | awk '{print $1}')"
echo "v4" > "$rootfs/usr/share/foo/foo.conf"
echo "$destsum  3.0" > "$rootfs/usr/share/foo/foo.conf.md5sum"
chroot "$rootfs" ucf -v --sum-file /usr/share/foo/foo.conf.md5sum \
    /usr/share/foo/foo.conf /etc/foo.conf > /tmp/output 2>&1
grep -q "Replacing config file /etc/foo.conf with new version" /tmp/output
test "$(cat "$rootfs/etc/foo.conf")" = "v4"
