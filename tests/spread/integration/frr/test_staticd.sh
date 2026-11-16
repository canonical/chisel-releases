#!/bin/bash
set -e

cp testfiles/staticd.conf "${rootfs}/etc/frr/frr.conf"

# the daemons keep whatever stdout they inherit, which would leave spread
# waiting on the pipe long after this script exits
chroot "${rootfs}" /usr/lib/frr/frrinit.sh start > "${rootfs}/tmp/frr-start.log" 2>&1
cat "${rootfs}/tmp/frr-start.log"

# route install is asynchronous
for __t in $(seq 1 10); do
	if timeout 10 chroot "${rootfs}" ip route | grep -q 1.0.0.1; then
		break
	fi
	sleep "$__t"
done

# frr's own RIB, which is decided without touching the kernel
timeout 10 chroot "${rootfs}" vtysh -c 'show ip route 1.0.0.1/32' | grep -q eth0

# and the kernel FIB
timeout 10 chroot "${rootfs}" ip route | grep -q 1.0.0.1
timeout 10 chroot "${rootfs}" ip route get 1.0.0.1 | grep -q 'dev eth0'
