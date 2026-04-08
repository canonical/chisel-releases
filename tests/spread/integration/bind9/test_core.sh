#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices bind9_core)"

# install bind9-dnsutils for testing (dig, nsupdate)
apt update
apt install -y bind9-dnsutils bind9-utils

# Make fake /dev/null and mount /proc
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"' EXIT

#------------------------------------------------------------------------------
# BIND 9 SETUP
#-------------------------------------------------------------------------------

# Copy the config files to the rootfs
cp db.test.local "${rootfs}/etc/bind/db.test.local"

# Create the rndc key (maintainer scripts)
chroot "${rootfs}/" rndc-confgen -a

# Configure bind9 to allow new zones being added with rndc
cat <<EOF > "${rootfs}/etc/bind/named.conf.options"
options {
  directory "/var/cache/bind";
  allow-new-zones yes;
};
EOF

# Use named-rrchecker to validate the A records from the zone file
grep ' IN A ' "${rootfs}/etc/bind/db.test.local" |
    awk '{print $2, $3, $4}' |
    xargs -I{} sh -c 'echo "$1" | chroot "$2/" named-rrchecker' _ {} "$rootfs"

#--------------------------------------------------------------------------------
# RUN DNS SERVER
#--------------------------------------------------------------------------------

# Start the bind9 server
chroot "${rootfs}/" named -c /etc/bind/named.conf
trap 'chroot "${rootfs}/" rndc stop || true' EXIT

# Wait for bind to start
until chroot "${rootfs}/" rndc status >/dev/null 2>&1; do
    sleep 0.2
done

# Dynamically add a zone to bind9 config with rndc (generates .nzd file)
chroot "${rootfs}/" rndc addzone test.local '{ type master; file "/etc/bind/db.test.local"; allow-update { any; }; };'

#--------------------------------------------------------------------------------
# TEST ASSERTIONS
#--------------------------------------------------------------------------------

# Test DNS resolution
dig @127.0.0.1 www.test.local | grep ';; ANSWER SECTION:'
dig @127.0.0.1 mail.test.local | grep ';; ANSWER SECTION:'

# Read the generated nzd file
chroot "${rootfs}/" named-nzd2nzf /var/cache/bind/_default.nzd | grep 'zone "test.local"'

# Use nsupdate to add a new record (generates journal file)
nsupdate <<EOF
server 127.0.0.1
zone test.local
update add test1.test.local. 3600 A 127.0.0.1
send
EOF

# Test the new record
dig @127.0.0.1 test1.test.local | grep ';; ANSWER SECTION:'

# Read the journal file to verify the update was recorded
chroot "${rootfs}/" named-journalprint "/etc/bind/db.test.local.jnl" | grep 'test1.test.local'
