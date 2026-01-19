#!/bin/bash

chroot "$rootfs" /usr/lib/frr/frrinit.sh stop

umount "${rootfs}/dev"
umount "${rootfs}/proc"
