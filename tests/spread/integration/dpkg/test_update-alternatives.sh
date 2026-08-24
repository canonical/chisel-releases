#!/bin/bash
#spellchecker: ignore rootfs diffutils

rootfs="$(install-slices dpkg_update-alternatives)"

chroot "$rootfs" update-alternatives --help 2>&1 | grep -iq "usage: update-alternatives"
chroot "$rootfs" update-alternatives --version | grep -iq "update-alternatives"

# non-existent alternative
chroot "$rootfs" update-alternatives --display foo 2>&1 | grep -iq "no alternatives"
! chroot "$rootfs" update-alternatives --list foo

# make test alternatives
echo "foo1" > "$rootfs/usr/bin/foo1"
echo "foo2" > "$rootfs/usr/bin/foo2"

# install higher priority
chroot "$rootfs" update-alternatives --install /usr/bin/foo foo /usr/bin/foo1 50 | \
    grep -q "using /usr/bin/foo1 to provide /usr/bin/foo (foo)"
# NOTE: /etc/alternatives/foo appears like a broken symlink from outside of the chroot
# but inside the chroot it should be correctly pointing to the selected alternative
test "$(readlink "$rootfs/usr/bin/foo")" = "/etc/alternatives/foo"
test "$(readlink "$rootfs/etc/alternatives/foo")" = "/usr/bin/foo1"

# install lower priority, should not change the selected alternative
chroot "$rootfs" update-alternatives --install /usr/bin/foo foo /usr/bin/foo2 30
test "$(readlink "$rootfs/usr/bin/foo")" = "/etc/alternatives/foo"
test "$(readlink "$rootfs/etc/alternatives/foo")" = "/usr/bin/foo1"

# test display
chroot "$rootfs" update-alternatives --display foo > /tmp/output
grep -q "foo - auto mode" /tmp/output
grep -q "/usr/bin/foo1 - priority 50" /tmp/output
grep -q "/usr/bin/foo2 - priority 30" /tmp/output

# test list
chroot "$rootfs" update-alternatives --list foo > /tmp/output
grep -q "/usr/bin/foo1" /tmp/output
grep -q "/usr/bin/foo2" /tmp/output

# select the lower priority alternative
chroot "$rootfs" update-alternatives --set foo /usr/bin/foo2
test "$(readlink "$rootfs/usr/bin/foo")" = "/etc/alternatives/foo"
test "$(readlink "$rootfs/etc/alternatives/foo")" = "/usr/bin/foo2"

# go back to auto
chroot "$rootfs" update-alternatives --auto foo
test "$(readlink "$rootfs/usr/bin/foo")" = "/etc/alternatives/foo"
test "$(readlink "$rootfs/etc/alternatives/foo")" = "/usr/bin/foo1"

# remove the higher priority alternative, should switch to the remaining one
chroot "$rootfs" update-alternatives --remove foo /usr/bin/foo1
test "$(readlink "$rootfs/usr/bin/foo")" = "/etc/alternatives/foo"
test "$(readlink "$rootfs/etc/alternatives/foo")" = "/usr/bin/foo2"
chroot "$rootfs" update-alternatives --list foo | grep -q "/usr/bin/foo2"
! chroot "$rootfs" update-alternatives --list foo | grep -q "/usr/bin/foo1"

# remove all
chroot "$rootfs" update-alternatives --remove-all foo
chroot "$rootfs" update-alternatives --display foo 2>&1 | grep -iq "no alternatives"
! test -L "$rootfs/usr/bin/foo"
