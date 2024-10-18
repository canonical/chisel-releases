#!/bin/bash
# Basic tests for git core binaries.
rootfs="${1}"

chroot "${rootfs}" git init
echo "Test" > "${rootfs}/test.txt"
chroot "${rootfs}" git add test.txt
chroot "${rootfs}" git config --global user.email "root@localhost"
chroot "${rootfs}" git config --global user.name "Test Runner"
chroot "${rootfs}" git commit -m test
[[ $(chroot "${rootfs}" git ls-files) == "test.txt" ]]
