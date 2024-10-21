#!/bin/bash
# Test for git daemon.
rootfs="${1}"

mkdir -p "${rootfs}/srv/git-test"
chroot "${rootfs}" git init /srv/git-test
chroot "${rootfs}" git daemon --verbose --export-all /srv/git-test &
daemon_pid=$!
chroot "${rootfs}" git clone git://localhost/git-test
kill $daemon_pid
