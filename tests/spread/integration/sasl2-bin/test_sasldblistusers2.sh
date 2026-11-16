#!/usr/bin/env bash
# spellchecker: ignore rootfs sasldb testrealm testuser testpass

# saslpasswd2 creates the database in its own rootfs
tools="$(install-slices sasl2-bin_saslpasswd2)"
echo "testpass" | chroot "$tools" saslpasswd2 -f /sasldb2 -p -c -u testrealm testuser

rootfs="$(install-slices sasl2-bin_sasldblistusers2)"
cp "$tools/sasldb2" "$rootfs/sasldb2"

out="$(chroot "$rootfs" sasldblistusers2 -f /sasldb2)"
echo "$out" | grep -q '^testuser@testrealm: userPassword$'
