#!/bin/sh

# Note: This test is adapted from FRR's official tests for deb packaging:
# https://github.com/FRRouting/frr/blob/master/debian/tests/zebra-lo

set -e

chroot "${rootfs}" /usr/lib/frr/frrinit.sh start

# these should be running by default
pgrep watchfrr
pgrep zebra
pgrep staticd

# check vtysh works at all
chroot "${rootfs}" vtysh -c 'show version'

# check zebra is properly talking to the kernel
chroot "${rootfs}" vtysh -c 'show interface lo' | grep -q LOOPBACK
