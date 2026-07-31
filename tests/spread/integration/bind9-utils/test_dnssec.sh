#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices bind9-utils_dnssec)"

# Make fake /dev/null and mount /proc
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"

# --------------------------------------------------
# SETUP
# --------------------------------------------------

# Create dnssec policy
cat <<EOF > "$rootfs/dnssec.conf"
dnssec-policy "test-policy" {
    keys {
        ksk lifetime unlimited algorithm rsasha256 2048;
        zsk lifetime 30d algorithm rsasha256 2048;
    };
};
EOF

# Prepare the zone file
mkdir -p "$rootfs/etc/bind"
cp db.test.local "$rootfs/etc/bind/db.test.local"

# -----------------------------------------------------------
# TEST DNSSEC FUNCTIONS
# -----------------------------------------------------------

# Smoke test dnssec-keyfromlabel - we don't have a real HSM to store a .private key
chroot "$rootfs" dnssec-keyfromlabel -h

# Instead, we generate a test Key-Signing-Key (KSK) pair manually
chroot "$rootfs" dnssec-keygen -a RSASHA256 -b 2048 -f KSK -n ZONE test.local
ksk_name="$(ls "$rootfs"/Ktest.local.*.key | xargs -n1 basename | cut -d'.' -f1-3)"

# Activate the key now and inactivate in 30 days
chroot "$rootfs" dnssec-settime -A now -I +30d "$ksk_name".key

# Key-Signing-Request (KSR) workflow:
# 1. Generate a Zone-Signing-Key (ZSK)
# 2. Create a KSR request for the ZSK
# 3. Sign the KSR using the previously generated KSK as the master key (-K option)
chroot "$rootfs" dnssec-ksr -l /dnssec.conf -k test-policy -e +30d keygen test.local
chroot "$rootfs" dnssec-ksr -l /dnssec.conf -k test-policy -i now -e +30d request test.local > "$rootfs/test.ksr"
chroot "$rootfs" dnssec-ksr -l /dnssec.conf -k test-policy -f /test.ksr -e +30d -K . sign test.local > "$rootfs/test.skr"

# Add the KSR response to the zone file.
# It should already contain the KSK and ZSK public keys from the previous steps
cat "$rootfs/test.skr" >> "$rootfs/etc/bind/db.test.local"

# Use dnssec-signzone to adopt the signatures from the KSR
chroot "$rootfs" dnssec-signzone -S -o test.local /etc/bind/db.test.local

# Verify signatures
chroot "$rootfs" dnssec-verify -o test.local /etc/bind/db.test.local.signed |
    grep -A2 "Zone fully signed:" | grep -A1 "KSKs: 1 active" | grep "ZSKs: 1 active"

# Generate DS record for the key with dnssec-dsfromkey
# Check the generated DS record matches the one from dnssec-signzone
ds_record_fromkey=$(chroot "$rootfs" dnssec-dsfromkey -f /etc/bind/db.test.local.signed test.local | tr -d '[:space:]')
if [[ "$ds_record_fromkey" != $(cat "$rootfs/dsset-test.local." | tr -d '[:space:]') ]]; then
    echo "DS record from dnssec-dsfromkey does not match the one from dnssec-signzone"
    exit 1
fi

# Test dnssec-cds produces an output
chroot "$rootfs" dnssec-cds -s 0 -f /etc/bind/db.test.local.signed -d . test.local | grep "test.local. IN DS"

# Revoke the KSK and create a new one (one KSK is always required)
chroot "$rootfs" dnssec-revoke -r "$ksk_name".key
chroot "$rootfs" dnssec-keygen -a RSASHA256 -A now -I +30d -b 2048 -f KSK -n ZONE test.local

# Resign the zone with the new keys (-RQ will remove inactive signatures)
chroot "$rootfs" dnssec-signzone -SRQ -o test.local /etc/bind/db.test.local

# Verify the revoked key is marked as revoked in the signed zone
chroot "$rootfs" dnssec-verify -o test.local /etc/bind/db.test.local.signed |
    grep -A2 "Zone fully signed:" | grep -A1 "KSKs: 1 active, 0 stand-by, 1 revoked" | grep "ZSKs: 1 active"