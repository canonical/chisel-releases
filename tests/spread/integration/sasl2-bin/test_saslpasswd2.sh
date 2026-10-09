#!/usr/bin/env bash
# spellchecker: ignore rootfs sasldb testrealm testuser testpass

rootfs="$(install-slices sasl2-bin_saslpasswd2)"

# the slice brings no /etc, so point saslpasswd2 at an explicit database
echo "testpass" | chroot "$rootfs" saslpasswd2 -f /sasldb2 -p -c -u testrealm testuser
test -s "$rootfs/sasldb2"

# and remove the user again
chroot "$rootfs" saslpasswd2 -f /sasldb2 -d -u testrealm testuser
