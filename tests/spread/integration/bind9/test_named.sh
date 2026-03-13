#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices bind9_bins)"

# install dnsutils and bind9-dnsutils for testing
apt update
apt install -y dnsutils bind9-dnsutils bind9-utils

# Make fake /dev/null and mount /proc
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
chmod +x "$rootfs/dev/null"
mkdir -p "$rootfs/proc"
sudo mount --bind /proc "$rootfs/proc"
trap 'sudo umount "$rootfs/proc"' EXIT

#------------------------------------------------------------------------------
# BIND 9 SETUP
#-------------------------------------------------------------------------------

# Create the rndc key (maintainer scripts)
rndc-confgen -a -t $rootfs

# Copy the config files to the rootfs
cp db.test.local "${rootfs}/etc/bind/db.test.local"

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
    xargs -I{} sh -c 'echo "{}" | chroot "${rootfs}/" named-rrchecker'

#--------------------------------------------------------------------------------
# RUN DNS SERVER
#--------------------------------------------------------------------------------

# Start the bind9 server
chroot "${rootfs}/" named -g -c /etc/bind/named.conf &
pid=$!
trap 'kill $pid' EXIT

# Wait for bind to start
sleep 5

# Dynamically add a zone to bind9 config with rndc (generates .nzd file)
rndc addzone test.local '{ type master; file "/etc/bind/db.test.local"; allow-update { any; }; };'

#--------------------------------------------------------------------------------
# TEST ASSERTIONS
#--------------------------------------------------------------------------------

# Test DNS resolution
dig @127.0.0.1 www.test.local | grep ';; ANSWER SECTION:'
dig @127.0.0.1 mail.test.local | grep ';; ANSWER SECTION:'

# Read the generated nzd file
chroot rootfs/ named-nzd2nzf /var/cache/bind/_default.nzd | grep 'zone "test.local"'

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
