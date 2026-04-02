#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices bind9_core bind9-utils_rndc)"

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

# Configure bind9 to allow new zones being added with rndc
cat <<EOF > "${rootfs}/etc/bind/named.conf.options"
options {
  directory "/var/cache/bind";
  allow-new-zones yes;
};
EOF

# Create the rndc key
chroot "${rootfs}/" rndc-confgen -a

#--------------------------------------------------------------------------------
# RUN DNS SERVER
#--------------------------------------------------------------------------------

chroot "${rootfs}/" named -c /etc/bind/named.conf
trap 'chroot "${rootfs}/" rndc stop || true' EXIT

#--------------------------------------------------------------------------------
# TEST RNDC COMMANDS
#--------------------------------------------------------------------------------

# Wait for bind to start
until chroot "${rootfs}/" rndc status; do
    sleep 0.2
done

# Dynamically add a zone to bind9 config with rndc
chroot "${rootfs}/" rndc addzone test.local '{ type master; file "/etc/bind/db.test.local"; allow-update { any; }; };'

# Check zone was added
chroot "${rootfs}/" rndc zonestatus test.local | grep "name: test.local"

# Remove the zone
chroot "${rootfs}/" rndc delzone test.local

# Reload the config
chroot "${rootfs}/" rndc reload

# Check zone was removed
chroot "${rootfs}/" rndc zonestatus test.local 2>&1 | grep "no matching zone 'test.local' in any view"

# Stop the server
chroot "${rootfs}/" rndc stop

# Check server is stopped
chroot "${rootfs}/" rndc status 2>&1 | grep "connection refused"
