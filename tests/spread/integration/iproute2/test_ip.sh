#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices iproute2_ip-bin)"

chroot "$rootfs" ip --help 2>&1 | grep -iq "usage: ip"
chroot "$rootfs" ip -V 2>&1 | grep -iq "ip utility, iproute2-"

chroot "$rootfs" ip link show
chroot "$rootfs" ip address show
chroot "$rootfs" ip route show
chroot "$rootfs" ip neigh show
