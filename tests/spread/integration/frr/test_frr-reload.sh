#!/bin/sh

# Note: This test is adapted from FRR's official tests for deb packaging:
# https://github.com/FRRouting/frr/blob/master/debian/tests/py-frr-reload

set -e

chroot "${rootfs}" /usr/lib/frr/frrinit.sh start

# these should be running by default
pgrep watchfrr
pgrep zebra
pgrep staticd

# configure interactively, save to file
chroot "${rootfs}" vtysh -c 'configure terminal' -c 'ip route 198.51.100.0/28 127.0.0.1'
chroot "${rootfs}" vtysh -c 'show running-config' | grep -q 'ip route 198.51.100.0/28 127.0.0.1'
chroot "${rootfs}" vtysh -c 'write memory'

grep -q 'ip route 198.51.100.0/28 127.0.0.1' "${rootfs}/etc/frr/frr.conf"

# configure in file, check interactively
sed -e '/^ip route 198.51.100.0\/28 127.0.0.1/ c ip route 198.51.100.64/28 127.0.0.1' \
	-i "${rootfs}/etc/frr/frr.conf"

chroot "${rootfs}" /usr/lib/frr/frr-reload

# wait for the new config to load
for __t in $(seq 1 10); do
	if chroot "${rootfs}" vtysh -c 'show running-config' | grep -q 'ip route 198.51.100.64/28 127.0.0.1'; then
		break
	fi
	sleep "$__t"
done

# fail if the old config is still loaded
if chroot "${rootfs}" vtysh -c 'show running-config' | grep -q 'ip route 198.51.100.0/28 127.0.0.1'; then
	exit 1
fi
