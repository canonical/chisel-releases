#!/bin/bash
set -e

cp configs/staticd.conf "${rootfs}/etc/frr/frr.conf"

chroot "${rootfs}" /usr/lib/frr/frrinit.sh start

sleep 2

chroot "${rootfs}" ip route | grep 1.0.0.1
chroot "${rootfs}" ip route get 1.0.0.1 | grep -e 'via.*dev eth0'
