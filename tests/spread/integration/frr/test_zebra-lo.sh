#!/bin/sh

# Note: This test is adapted from FRR's official tests for deb packaging:
# https://github.com/FRRouting/frr/blob/master/debian/tests/zebra-lo

set -e

# the daemons keep whatever stdout they inherit, which would leave spread
# waiting on the pipe long after this script exits
chroot "${rootfs}" /usr/lib/frr/frrinit.sh start > "${rootfs}/tmp/frr-start.log" 2>&1
cat "${rootfs}/tmp/frr-start.log"

# these should be running by default
pgrep watchfrr
pgrep zebra
pgrep staticd

# check vtysh works at all
timeout 10 chroot "${rootfs}" vtysh -c 'show version'

# check zebra is properly talking to the kernel
timeout 10 chroot "${rootfs}" vtysh -c 'show interface lo' | grep -q LOOPBACK
