#!/usr/bin/env bash
# spellchecker: ignore rootfs lladdr

rootfs="$(install-slices iproute2_ip-bin)"

chroot "$rootfs" ip --help 2>&1 | grep -iq "usage: ip"
chroot "$rootfs" ip -V 2>&1 | grep -iq "ip utility, iproute2-"

chroot "$rootfs" ip link show | grep -iq "loopback"
chroot "$rootfs" ip address show | grep -iq "loopback"
chroot "$rootfs" ip route show | grep -iq "default via"
chroot "$rootfs" ip neigh show | grep -iq "lladdr"
