#!/bin/bash
#spellchecker: ignore rootfs conffile colons

# ucfr writes the registry and ucfq reads it, so the two only agree if they
# share both the on-disk format and the state directory.
rootfs="$(install-slices ucf_ucfr ucf_ucfq)"
mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null"
state=/var/lib/ucf-test

mkdir -p "$rootfs/etc"
echo a > "$rootfs/etc/a.conf"
echo b > "$rootfs/etc/b.conf"

chroot "$rootfs" ucfr --state-dir "$state" mypkg /etc/a.conf
chroot "$rootfs" ucfr --state-dir "$state" mypkg /etc/b.conf

# querying by file resolves the owning package
test "$(chroot "$rootfs" ucfq --state-dir "$state" --with-colons /etc/a.conf)" = \
    "/etc/a.conf:mypkg:Yes:"

# querying by package lists every file it owns, sorted
chroot "$rootfs" ucfq --state-dir "$state" --with-colons mypkg > /tmp/output
test "$(wc -l < /tmp/output)" -eq 2
test "$(head -n 1 /tmp/output)" = "/etc/a.conf:mypkg:Yes:"
test "$(tail -n 1 /tmp/output)" = "/etc/b.conf:mypkg:Yes:"

# the default state directory is untouched by any of the above
! test -e "$rootfs/var/lib/ucf/registry"

# and a purge round-trips too
chroot "$rootfs" ucfr --state-dir "$state" --purge mypkg /etc/a.conf
test -z "$(chroot "$rootfs" ucfq --state-dir "$state" --with-colons mypkg | grep a.conf)"
