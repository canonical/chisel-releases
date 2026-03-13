#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices bind9_bins)"

# Setup environment
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"

#------------------------------------------------------
# Test nsec3hash
#------------------------------------------------------
chroot $rootfs nsec3hash A1B2 1 1 www.test.com |
    grep "D74DR843CHDHF73C0P2DEM4B3SP44A4Q (salt=A1B2, hash=1, iterations=1"

#------------------------------------------------------
# Test ddns-confgen
#------------------------------------------------------
chroot $rootfs ddns-confgen -a hmac-sha256 -k testkey |
    grep "key \"testkey\" {" -A 2

#------------------------------------------------------
# Test tsig-keygen
#------------------------------------------------------
chroot $rootfs tsig-keygen -a hmac-sha256 testkey |
    grep "key \"testkey\" {" -A 2

#------------------------------------------------------
# Test dnssec-importkey
#------------------------------------------------------

# Install bind9-utils to get dnssec-keygen
apt-get update
apt-get install -y bind9-utils

# Generate a test DNSSEC key (ZSK) outside the chroot
dnssec-keygen -a RSASHA256 -b 2048 -n ZONE test.local

# Prepare a "zone file" containing that key for dnssec-importkey to read
cp db.test.local "$rootfs/etc/bind/db.test.local"
cat Ktest.local.*.key >> "$rootfs/etc/bind/db.test.local"

# Import the key using dnssec-importkey inside the chroot
chroot "$rootfs" dnssec-importkey -f /etc/bind/db.test.local -K /etc/bind test.local

# Verify output
ls "$rootfs/etc/bind/Ktest.local."*
