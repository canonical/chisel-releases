#!/bin/bash
#spellchecker: ignore rootfs conffile

rootfs="$(install-slices ucf_ucfr)"
mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null"
reg="$rootfs/var/lib/ucf/registry"

chroot "$rootfs" ucfr --help 2>&1 | grep -iq "usage: ucfr"

mkdir -p "$rootfs/etc"
echo x > "$rootfs/etc/myapp.conf"

# the first registration creates the state directory and the registry itself
chroot "$rootfs" ucfr myapp /etc/myapp.conf
grep -Eq "^myapp[[:space:]]+/etc/myapp\.conf$" "$reg"

# repeating it is a no-op
before="$(cat "$reg")"
chroot "$rootfs" ucfr -v myapp /etc/myapp.conf 2>&1 | grep -q "Association already recorded"
test "$before" = "$(cat "$reg")"

# a symlinked path is recorded under its resolved target
echo target > "$rootfs/etc/real.conf"
ln -s /etc/real.conf "$rootfs/etc/link.conf"
chroot "$rootfs" ucfr mypkg /etc/link.conf
grep -Eq "^mypkg[[:space:]]+/etc/real\.conf$" "$reg"
! grep -q "link.conf" "$reg"

# argument errors
rc=0; chroot "$rootfs" ucfr > /tmp/output 2>&1 || rc=$?
test "$rc" -eq 1
grep -q "Unable to determine The Package name" /tmp/output

rc=0; chroot "$rootfs" ucfr myapp > /tmp/output 2>&1 || rc=$?
test "$rc" -eq 1
grep -q "Unable to determine The Configuration file" /tmp/output

rc=0; chroot "$rootfs" ucfr myapp /etc/myapp.conf extra > /tmp/output 2>&1 || rc=$?
test "$rc" -eq 3
grep -q "Need exactly two arguments, got 3" /tmp/output

# a second package cannot take over an association without being forced
echo x > "$rootfs/etc/shared.conf"
chroot "$rootfs" ucfr pkgA /etc/shared.conf
rc=0; chroot "$rootfs" ucfr pkgB /etc/shared.conf > /tmp/output 2>&1 || rc=$?
test "$rc" -eq 4
grep -q "Attempt from package pkgB" /tmp/output
grep -Eq "^pkgA[[:space:]]+/etc/shared\.conf$" "$reg"

chroot "$rootfs" ucfr --force pkgB /etc/shared.conf
grep -Eq "^pkgB[[:space:]]+/etc/shared\.conf$" "$reg"

# nor purge one it does not own
rc=0; chroot "$rootfs" ucfr --purge pkgA /etc/shared.conf > /tmp/output 2>&1 || rc=$?
test "$rc" -eq 5
grep -q "Association belongs to pkgB, not pkgA" /tmp/output
grep -q "/etc/shared.conf" "$reg"

chroot "$rootfs" ucfr --purge --force pkgA /etc/shared.conf
! grep -q "/etc/shared.conf" "$reg"
# every write rotates the previous generation out of the way
grep -q "/etc/shared.conf" "$rootfs/var/lib/ucf/registry.0"

# a dry run reports what it would do and leaves the registry alone
before="$(cat "$reg")"
chroot "$rootfs" ucfr -n newpkg /etc/other.conf 2>&1 | grep -qx "replace_in_registry"
test "$before" = "$(cat "$reg")"

# duplicate entries for one file are treated as corruption
echo y > "$rootfs/etc/dup.conf"
printf 'pkgA\t /etc/dup.conf\npkgB\t /etc/dup.conf\n' >> "$reg"
rc=0; chroot "$rootfs" ucfr pkgA /etc/dup.conf > /tmp/output 2>&1 || rc=$?
test "$rc" -eq 2
grep -q "Corrupt registry: Duplicate entries" /tmp/output
