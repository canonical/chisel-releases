#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices bind9_standard)"

# Setup environment
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"

#-------------------------------------------------------
# Test arpaname
#-------------------------------------------------------
chroot $rootfs arpaname 123.145.167.189 | grep 189.167.145.123.IN-ADDR.ARPA
chroot $rootfs arpaname 127.0.0.1 | grep 1.0.0.127.IN-ADDR.ARPA
chroot $rootfs arpaname 8.8.8.8 | grep 8.8.8.8.IN-ADDR.ARPA

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

# Generate a test DNSSEC key (ZSK)
chroot "$rootfs" dnssec-keygen -a RSASHA256 -b 2048 -n ZONE test.local

# Prepare a "zone file" containing that key for dnssec-importkey to read
cp db.test.local "$rootfs/etc/bind/db.test.local"
cat "$rootfs"/Ktest.local.*.key >> "$rootfs/etc/bind/db.test.local"

# Import the key using dnssec-importkey to generate a new .private key file
chroot "$rootfs" dnssec-importkey -f /etc/bind/db.test.local -K /etc/bind test.local

# Verify output
ls "$rootfs/etc/bind/Ktest.local."*
